#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VERIFIER DOC LAP cho tap con WildReceipt (bench-prep/lab-wildreceipt/).

Doc tu dia, KHONG import select_wildreceipt (tu viet lai cac luat kiem):
 1. CSV co dung 24 dong, case_id W-01..W-24 lien tuc, 4 tang x 6 theo
    thu tu LONG/DENSE/LOWRES/TALL.
 2. Moi file anh ton tai duoi corpus/lab/wildreceipt/extracted/
    wildreceipt/, sha256 + byte-size khop CSV.
 3. Moi ca du dieu kien §3.1 tu nhan goc: co Total/Date/Subtotal/Item/
    Price + hop >= 35 + mon >= 4 (dem lai tu test.txt).
 4. Van ban nhan tho trong CSV (tiem/ngay/subtotal/thue/tips/total)
    khop tung ky tu voi nhan goc doc theo thu tu doc.
 5. Cac cot so (width/height/n_*/median/aspect/xu-phan-tich-dau)
    khop so dem lai (lam tron nhu selector: median 1 so le,
    aspect 3 so le).
 6. Khong cap nao trong 24 ca la trung giao dich theo khoa mo
    (ngay-so + subtotal-giao + tiem giong >= 0.75, hoac tiem bang +
    ngay + total-giao).
 7. Tai lap: chay lai select_wildreceipt.py ra thu muc tam — CSV
    byte-trung voi CSV da dong bang.
In PASS/FAIL tung nhom + dong ket. Exit 1 neu co FAIL.
"""
import csv
import hashlib
import json
import os
import statistics
import subprocess
import sys
import tempfile
from collections import Counter
from difflib import SequenceMatcher

HERE = os.path.dirname(os.path.abspath(__file__))
WR_ROOT = os.path.join(
    HERE, "..", "..", "corpus", "lab", "wildreceipt", "extracted", "wildreceipt"
)
L_STORE, L_DATE, L_SUBTOTAL, L_TAX, L_TIPS, L_TOTAL = 1, 7, 17, 19, 21, 23
L_ITEM, L_QTY, L_PRICE = 11, 13, 15

failures = []


def check(label, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {label}  {detail}")
    if not ok:
        failures.append(label)


def texts(rec, label):
    ann = [a for a in rec["annotations"] if a["label"] == label]
    ann.sort(key=lambda a: (min(a["box"][1::2]), min(a["box"][0::2])))
    return [a["text"] for a in ann]


def money(text):
    t = "".join(ch for ch in text if ch.isdigit() or ch in ".,-").rstrip("-")
    if not t or t in {".", ",", "-", "-."}:
        return None
    if "," in t and "." not in t:
        p = t.split(",")
        t = p[0] + "." + p[1] if len(p) == 2 and len(p[1]) == 2 else t.replace(",", "")
    else:
        t = t.replace(",", "")
    try:
        return int(round(float(t) * 100))
    except ValueError:
        return None


def cents_set(rec, label):
    return {v for v in (money(x) for x in texts(rec, label)) if v is not None}


def first_cents(rec, label):
    for x in texts(rec, label):
        v = money(x)
        if v is not None:
            return v
    return None


def dup_pair(a, b):
    da = frozenset("".join(ch for ch in d if ch.isdigit()) for d in texts(a, L_DATE))
    db = frozenset("".join(ch for ch in d if ch.isdigit()) for d in texts(b, L_DATE))
    if not da or da != db:
        return False
    sa = "".join(ch for ch in "".join(texts(a, L_STORE)).upper() if ch.isalnum())
    sb = "".join(ch for ch in "".join(texts(b, L_STORE)).upper() if ch.isalnum())
    if sa and sb and cents_set(a, L_SUBTOTAL) & cents_set(b, L_SUBTOTAL) \
            and SequenceMatcher(None, sa, sb).ratio() >= 0.75:
        return True
    return bool(sa and sa == sb and cents_set(a, L_TOTAL) & cents_set(b, L_TOTAL))


def main():
    recs = {}
    for line in open(os.path.join(WR_ROOT, "test.txt"), encoding="utf-8"):
        r = json.loads(line)
        recs[r["file_name"]] = r

    with open(os.path.join(HERE, "wildreceipt-subset.csv"), encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    check("24 dong + case_id lien tuc",
          len(rows) == 24 and [r["case_id"] for r in rows] == [f"W-{i:02d}" for i in range(1, 25)],
          f"rows={len(rows)}")
    strata = [r["stratum"] for r in rows]
    check("4 tang x 6 dung thu tu",
          strata == ["LONG"] * 6 + ["DENSE"] * 6 + ["LOWRES"] * 6 + ["TALL"] * 6,
          f"{Counter(strata)}")

    bad_hash, bad_gate, bad_raw, bad_num = [], [], [], []
    for row in rows:
        path = os.path.join(WR_ROOT, row["file_name"])
        if not os.path.exists(path):
            bad_hash.append(row["case_id"] + ":missing")
            continue
        data = open(path, "rb").read()
        if hashlib.sha256(data).hexdigest() != row["sha256"] or len(data) != int(row["bytes"]):
            bad_hash.append(row["case_id"])
        rec = recs.get(row["file_name"])
        if rec is None:
            bad_gate.append(row["case_id"] + ":not-in-test")
            continue
        c = Counter(a["label"] for a in rec["annotations"])
        if not (c[L_TOTAL] and c[L_DATE] and c[L_SUBTOTAL] and c[L_ITEM] and c[L_PRICE]
                and len(rec["annotations"]) >= 35 and c[L_ITEM] >= 4):
            bad_gate.append(row["case_id"])
        raw_expect = {
            "store_raw": " | ".join(texts(rec, L_STORE)),
            "date_raw": " | ".join(texts(rec, L_DATE)),
            "subtotal_raw": " | ".join(texts(rec, L_SUBTOTAL)),
            "tax_raw": " | ".join(texts(rec, L_TAX)),
            "tips_raw": " | ".join(texts(rec, L_TIPS)),
            "total_raw": " | ".join(texts(rec, L_TOTAL)),
        }
        for k, v in raw_expect.items():
            if row[k] != v:
                bad_raw.append(f"{row['case_id']}:{k}")
        hs = [max(a["box"][1::2]) - min(a["box"][1::2]) for a in rec["annotations"]]
        num_expect = {
            "width": str(rec["width"]), "height": str(rec["height"]),
            "n_annotations": str(len(rec["annotations"])),
            "n_prod_item": str(c[L_ITEM]), "n_prod_price": str(c[L_PRICE]),
            "n_prod_qty": str(c[L_QTY]),
            "median_box_height_px": f"{statistics.median(hs):.1f}",
            "aspect_h_w": f"{rec['height'] / rec['width']:.3f}",
            "subtotal_cents_first": "" if first_cents(rec, L_SUBTOTAL) is None else str(first_cents(rec, L_SUBTOTAL)),
            "total_cents_first": "" if first_cents(rec, L_TOTAL) is None else str(first_cents(rec, L_TOTAL)),
        }
        for k, v in num_expect.items():
            if row[k] != v:
                bad_num.append(f"{row['case_id']}:{k}")
    check("sha256 + byte-size khop dia 24/24", not bad_hash, ",".join(bad_hash))
    check("moi ca qua cua §3.1 + cua do kho (dem lai)", not bad_gate, ",".join(bad_gate))
    check("van ban nhan tho khop tung ky tu", not bad_raw, ",".join(bad_raw))
    check("cot so khop so dem lai", not bad_num, ",".join(bad_num))

    sel = [recs[r["file_name"]] for r in rows]
    dups = [(rows[i]["case_id"], rows[j]["case_id"])
            for i in range(len(sel)) for j in range(i + 1, len(sel))
            if dup_pair(sel[i], sel[j])]
    check("0 cap trung giao dich trong 24 ca", not dups, str(dups))

    with tempfile.TemporaryDirectory() as td:
        subprocess.run(
            [sys.executable, os.path.join(HERE, "select_wildreceipt.py"), "--out-dir", td],
            check=True, capture_output=True, text=True)
        orig = open(os.path.join(HERE, "wildreceipt-subset.csv"), "rb").read()
        redo = open(os.path.join(td, "wildreceipt-subset.csv"), "rb").read()
        check("tai lap byte-trung CSV khi chay lai selector", orig == redo,
              f"{len(orig)} vs {len(redo)} byte")

    print("KET LUAN:", "PASS" if not failures else f"FAIL {failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
