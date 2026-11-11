#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CHON TAP CON KHO WildReceipt (lan lab) — theo core-redo/ACCEPTANCE.md §3.1.

Muc dich: dong bang DANH SACH ca lab da chon cho dieu kien chan buoi do
§3.5(2). Lan lab CHI do do ben, KHONG PHAI cong (Master Plan §3.3);
ket qua lan nay khong bao gio trinh nhu "so mon dat" — nhan WildReceipt
khong cho so mon ngoai dang tin (ACCEPTANCE §3.1).

Tieu chi §3.1 dich thanh cong thuc do duoc tren nhan hop (test.txt):
  BAT BUOC (cua cung):
    - co nhan Total_value (label 23) + Date_value (7) + Subtotal_value (17)
      [giao cua 3 dieu kien §3.1 ghi: total 423/472, date 398/472,
       subtotal 343/472 — so dem lai trong lan chay nay, ghi o results]
    - co Prod_item_value (11) + Prod_price_value (15): dieu kien de ca
      cham duoc dang thuc NOI BO E1 tren may (app doc duoc subtotal nao
      thi Sigma mon app doc phai khop subtotal do — can co mon that).
    - file anh ton tai tren dia, byte > 0.
  TRUNG GIAO DICH (loai truoc khi xep hang): 2 to la TRUNG neu
    (ngay chi gom chu so bang nhau) VA (tap xu subtotal giao nhau)
    VA (ten tiem chuan hoa giong nhau >= 0.75 theo SequenceMatcher),
    HOAC (ten tiem chuan hoa bang nhau + ngay bang nhau + tap xu total
    giao nhau). Ly do can khoa mo: nhan dataset co nhieu ban chup lai
    CUNG mot giao dich ma nhan total/ten tiem lech nhau do loi gan nhan
    (vd ElBorracho: total 136.50 vs 136.95; ILIO'S vs ILTO'S).
    Moi nhom trung giu 1 to: nhieu diem anh nhat, hoa thi file_name nho.
  CUA DO KHO (ap cho moi tang):
    - tong so hop chu thich >= 35 VA so Prod_item_value >= 4.
  4 TANG DO KHO x 6 ca = 24 ca, chon tham lam theo thu tu tang co dinh,
  khong to nao dung 2 lan:
    LONG   — nhieu dong mon nhat:  khoa (-n_item, -n_ann, file_name)
    DENSE  — chu nho nhat (kho doc): khoa (median cao hop px, -n_ann, file)
    LOWRES — anh hep nhat:          khoa (width, -n_ann, file_name)
    TALL   — to dai nhat:           khoa (-height/width, -n_ann, file)
  KHONG do duoc tu nhan hop: nhan/mo/phai that — bo chon nay KHONG
  khang dinh cac tinh chat do; no chi khang dinh cac truc do o tren.

Dap an ghi o bang ke la VAN BAN NHAN NGUYEN VAN (doc theo thu tu
tren->duoi, trai->phai cua hop). Cot xu (subtotal_cents / total_cents)
la gia tri PHAN TICH DUOC DAU TIEN theo thu tu doc — chi de tham chieu;
van ban tho la ban co quyen. Nhieu to co nhieu hop total trung gia tri.

Deterministic: khong random, moi sap xep co khoa phu file_name.
Chay: python3 select_wildreceipt.py [--out-dir DIR]
Xuat: wildreceipt-subset.csv + selection-results.txt trong out-dir.
"""
import argparse
import csv
import hashlib
import json
import os
import statistics
import sys
from collections import Counter
from difflib import SequenceMatcher

HERE = os.path.dirname(os.path.abspath(__file__))
WR_ROOT = os.path.join(
    HERE, "..", "..", "corpus", "lab", "wildreceipt", "extracted", "wildreceipt"
)
TEST_TXT = os.path.join(WR_ROOT, "test.txt")

# Nhan lop theo class_list.txt cua MMOCR WildReceipt
L_STORE, L_DATE, L_SUBTOTAL, L_TAX, L_TIPS, L_TOTAL = 1, 7, 17, 19, 21, 23
L_ITEM, L_QTY, L_PRICE = 11, 13, 15

MIN_ANNOTATIONS = 35
MIN_ITEMS = 4
PER_STRATUM = 6


def texts_in_reading_order(rec, label):
    ann = [a for a in rec["annotations"] if a["label"] == label]
    ann.sort(key=lambda a: (min(a["box"][1::2]), min(a["box"][0::2])))
    return [a["text"] for a in ann]


def parse_money_cents(text):
    """Phan tich 1 hop tien -> xu, hoac None. Bo ky hieu tien te va chu;
    phay la dau thap phan chi khi dang '123,45' khong co dau cham;
    dau '-' o cuoi (ghi am kieu cu) bi bo qua cho muc dich khoa trung/
    tham chieu — van ban tho van la ban co quyen trong bang ke."""
    if text is None:
        return None
    t = "".join(ch for ch in text if ch.isdigit() or ch in ".,-")
    t = t.rstrip("-")
    if not t or t in {".", ",", "-", "-."}:
        return None
    if "," in t and "." not in t:
        parts = t.split(",")
        if len(parts) == 2 and len(parts[1]) == 2:
            t = parts[0] + "." + parts[1]
        else:
            t = t.replace(",", "")
    else:
        t = t.replace(",", "")
    try:
        return int(round(float(t) * 100))
    except ValueError:
        return None


def first_parseable_cents(rec, label):
    for txt in texts_in_reading_order(rec, label):
        v = parse_money_cents(txt)
        if v is not None:
            return v
    return None


def cents_set(rec, label):
    out = set()
    for txt in texts_in_reading_order(rec, label):
        v = parse_money_cents(txt)
        if v is not None:
            out.add(v)
    return out


def date_digits(rec):
    return frozenset(
        "".join(ch for ch in d if ch.isdigit())
        for d in texts_in_reading_order(rec, L_DATE)
    )


def store_norm(rec):
    joined = "".join(texts_in_reading_order(rec, L_STORE)).upper()
    return "".join(ch for ch in joined if ch.isalnum())


def is_duplicate_pair(a, b):
    if date_digits(a) != date_digits(b) or not date_digits(a):
        return False
    sa, sb = store_norm(a), store_norm(b)
    if sa and sb and cents_set(a, L_SUBTOTAL) & cents_set(b, L_SUBTOTAL):
        if SequenceMatcher(None, sa, sb).ratio() >= 0.75:
            return True
    if sa and sb and sa == sb and cents_set(a, L_TOTAL) & cents_set(b, L_TOTAL):
        return True
    return False


def dedupe(recs):
    """Union-find theo cap trung; moi nhom giu to nhieu diem anh nhat."""
    parent = list(range(len(recs)))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for i in range(len(recs)):
        for j in range(i + 1, len(recs)):
            if is_duplicate_pair(recs[i], recs[j]):
                ri, rj = find(i), find(j)
                if ri != rj:
                    parent[rj] = ri
    groups = {}
    for i, r in enumerate(recs):
        groups.setdefault(find(i), []).append(r)
    kept, n_removed, n_groups = [], 0, 0
    for members in groups.values():
        if len(members) > 1:
            n_groups += 1
            n_removed += len(members) - 1
        members.sort(key=lambda r: (-(r["width"] * r["height"]), r["file_name"]))
        kept.append(members[0])
    kept.sort(key=lambda r: r["file_name"])
    return kept, n_removed, n_groups


def median_box_height_px(rec):
    hs = []
    for a in rec["annotations"]:
        ys = a["box"][1::2]
        hs.append(max(ys) - min(ys))
    return statistics.median(hs) if hs else 0.0


def metrics(rec):
    c = Counter(a["label"] for a in rec["annotations"])
    return {
        "n_annotations": len(rec["annotations"]),
        "n_item": c[L_ITEM],
        "n_price": c[L_PRICE],
        "n_qty": c[L_QTY],
        "median_box_h": median_box_height_px(rec),
        "aspect": rec["height"] / rec["width"] if rec["width"] else 0.0,
    }


STRATA = [
    ("LONG", lambda m: (-m["n_item"], -m["n_annotations"])),
    ("DENSE", lambda m: (m["median_box_h"], -m["n_annotations"])),
    ("LOWRES", None),  # khoa dac biet: width cua rec
    ("TALL", lambda m: (-m["aspect"], -m["n_annotations"])),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default=HERE)
    args = ap.parse_args()
    os.makedirs(args.out_dir, exist_ok=True)

    rows = [json.loads(line) for line in open(TEST_TXT, encoding="utf-8")]
    funnel = []
    funnel.append(f"test split tong: {len(rows)}")

    def has(rec, label):
        return any(a["label"] == label for a in rec["annotations"])

    n_total = sum(1 for r in rows if has(r, L_TOTAL))
    n_date = sum(1 for r in rows if has(r, L_DATE))
    n_sub = sum(1 for r in rows if has(r, L_SUBTOTAL))
    funnel.append(
        f"phu nhan (doi chieu ACCEPTANCE §3.1): total {n_total} · "
        f"date {n_date} · subtotal {n_sub}"
    )
    elig = [r for r in rows if has(r, L_TOTAL) and has(r, L_DATE) and has(r, L_SUBTOTAL)]
    funnel.append(f"qua cua total+date+subtotal (§3.1): {len(elig)}")
    elig2 = [r for r in elig if has(r, L_ITEM) and has(r, L_PRICE)]
    funnel.append(f"them cua item+price (can cho E1 noi bo): {len(elig2)}")
    kept, n_removed, n_groups = dedupe(elig2)
    funnel.append(
        f"sau loai trung giao dich: {len(kept)} "
        f"(loai {n_removed} ban trung thuoc {n_groups} nhom)"
    )
    gated = []
    for r in kept:
        m = metrics(r)
        if m["n_annotations"] >= MIN_ANNOTATIONS and m["n_item"] >= MIN_ITEMS:
            gated.append((r, m))
    funnel.append(
        f"qua cua do kho (hop >= {MIN_ANNOTATIONS} va mon >= {MIN_ITEMS}): "
        f"{len(gated)}"
    )

    picked = []  # (stratum, rec, metrics)
    used = set()
    for name, keyfn in STRATA:
        cand = [(r, m) for (r, m) in gated if r["file_name"] not in used]
        if name == "LOWRES":
            cand.sort(key=lambda rm: (rm[0]["width"], -rm[1]["n_annotations"], rm[0]["file_name"]))
        else:
            cand.sort(key=lambda rm: (keyfn(rm[1]), rm[0]["file_name"]))
        for r, m in cand[:PER_STRATUM]:
            picked.append((name, r, m))
            used.add(r["file_name"])
    funnel.append(f"da chon: {len(picked)} ca (4 tang x {PER_STRATUM})")

    csv_path = os.path.join(args.out_dir, "wildreceipt-subset.csv")
    fieldnames = [
        "case_id", "stratum", "file_name", "sha256", "bytes", "width", "height",
        "n_annotations", "n_prod_item", "n_prod_price", "n_prod_qty",
        "median_box_height_px", "aspect_h_w",
        "store_raw", "date_raw", "subtotal_raw", "tax_raw", "tips_raw",
        "total_raw", "subtotal_cents_first", "total_cents_first",
        "scoring_use",
    ]
    scoring_use = "M1/M2 dung-hoac-co + E1/E2 dang thuc noi bo; KHONG so mon ngoai"
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for idx, (stratum, r, m) in enumerate(picked, start=1):
            img_path = os.path.join(WR_ROOT, r["file_name"])
            data = open(img_path, "rb").read()
            sub_c = first_parseable_cents(r, L_SUBTOTAL)
            tot_c = first_parseable_cents(r, L_TOTAL)
            w.writerow({
                "case_id": f"W-{idx:02d}",
                "stratum": stratum,
                "file_name": r["file_name"],
                "sha256": hashlib.sha256(data).hexdigest(),
                "bytes": len(data),
                "width": r["width"],
                "height": r["height"],
                "n_annotations": m["n_annotations"],
                "n_prod_item": m["n_item"],
                "n_prod_price": m["n_price"],
                "n_prod_qty": m["n_qty"],
                "median_box_height_px": f"{m['median_box_h']:.1f}",
                "aspect_h_w": f"{m['aspect']:.3f}",
                "store_raw": " | ".join(texts_in_reading_order(r, L_STORE)),
                "date_raw": " | ".join(texts_in_reading_order(r, L_DATE)),
                "subtotal_raw": " | ".join(texts_in_reading_order(r, L_SUBTOTAL)),
                "tax_raw": " | ".join(texts_in_reading_order(r, L_TAX)),
                "tips_raw": " | ".join(texts_in_reading_order(r, L_TIPS)),
                "total_raw": " | ".join(texts_in_reading_order(r, L_TOTAL)),
                "subtotal_cents_first": "" if sub_c is None else sub_c,
                "total_cents_first": "" if tot_c is None else tot_c,
                "scoring_use": scoring_use,
            })

    elig_ann = [metrics(r)["n_annotations"] for r in kept]
    elig_item = [metrics(r)["n_item"] for r in kept]
    pick_ann = [m["n_annotations"] for _, _, m in picked]
    pick_item = [m["n_item"] for _, _, m in picked]
    lines = []
    lines.append("CHON TAP CON KHO WildReceipt — KET QUA CHAY select_wildreceipt.py")
    lines.append("Nguon: corpus/lab/wildreceipt/extracted/wildreceipt/test.txt (472 to)")
    lines.append("")
    lines.append("== PHIEU LOC (funnel) ==")
    lines.extend(funnel)
    lines.append("")
    lines.append("== DO KHO: tap da chon vs tap du dieu kien sau trung ==")
    lines.append(
        f"hop chu thich trung vi: da chon {statistics.median(pick_ann)} "
        f"vs du dieu kien {statistics.median(elig_ann)}"
    )
    lines.append(
        f"dong mon trung vi: da chon {statistics.median(pick_item)} "
        f"vs du dieu kien {statistics.median(elig_item)}"
    )
    lines.append("")
    lines.append("== DANH SACH 24 CA ==")
    for idx, (stratum, r, m) in enumerate(picked, start=1):
        lines.append(
            f"W-{idx:02d} [{stratum}] hop={m['n_annotations']} mon={m['n_item']} "
            f"gia={m['n_price']} {r['width']}x{r['height']} "
            f"aspect={m['aspect']:.2f} chu_trung_vi={m['median_box_h']:.1f}px "
            f"{r['file_name']}"
        )
    with open(os.path.join(args.out_dir, "selection-results.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
