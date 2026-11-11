#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CỔNG G2 — BỘ SUY BIẾN CHỮ (ACCEPTANCE §3.3 / §5 cổng G2 / §3.5 điều kiện 1).

Nguồn luồng đóng băng:
  001 = parser-prototype/sample001-raw-text.txt   (luồng Vision THẬT)
  003 = samples/sample-003-ocr-raw.txt            (luồng OCR thô THẬT)
  002 = m1fix/fixtures.py ROWS_002 + HEADER_002   (TÁI DỰNG — ghi nhãn rõ;
        chỉ dùng cho 1 ca xé cột dòng tổng, không kết luận gì riêng về 002)

Sáu họ bệnh theo §3.3, mọi phép đều mô phỏng bệnh ĐÃ CÓ BẰNG CHỨNG:
  SPLIT  xé cột / xé dòng (bệnh gốc của 002; ca C3 của reconcile)
  DROP   mất dòng có kiểm soát (ca thực địa run #26: mất món, thiếu $34.46)
  NOISE  nhiễu ký tự trong token tiền (0<->O, mất dấu chấm thập phân...)
  BEFORE tiền-ở-dòng-TRƯỚC-nhãn (dạng thật của 003; hazard G4 cũ)
  DUP    trùng mảnh vùng chồng lát cắt (cơ chế lát 1600/200 chồng nhau)
  GARB   dòng rác lẫn (sự cố 16:19: "28200860 / IV Z / 9969080000")

Bộ máy bị chấm: port trung thực m1fix/port.py parse(fixed=True) +
mirror core-redo/reconcile.py — đúng cặp đã đối chiếu với Swift ở
p2-3/crosscheck.py (13/13). Đây là tầng T3+T4; KHÔNG đo T1/T2.

Phán quyết Lớp D (§2.3) cho TỪNG ca — đúng một trong ba:
  CORRECT          r2 (sau reconcile) đạt E1+E2+E3 và mọi số trình ra
                   (subtotal / thuế từng dòng / total) khớp đáp án đóng băng.
  CORRECT-REPAIRED như CORRECT nhưng reconcile có áp sửa có-cờ (inferred)
                   hoặc requiresReview — số đúng VÀ có cờ, đúng kỷ luật.
  FLAGGED          không CORRECT, nhưng MỌI đẳng thức vỡ / số sai đều có
                   cờ bao phủ: cảnh báo validate đúng phép (V1 tổng món /
                   V2 subtotal+thuế / V4 số lượng / thiếu tổng) hoặc trạng
                   thái reconcile != OK / requiresReview / taxMissing.
  SILENT-WRONG     có số sai hoặc đẳng thức vỡ mà KHÔNG cờ bao phủ tương
                   ứng -> ca RỚT, và 1 ca như vậy là RỚT TOÀN BỘ CỔNG G2.

Chạy: python3 bench-prep/text-degrade/run_text_degrade.py
Xuất: flows/Tnn.txt (luồng suy biến đã đóng băng) +
      text-degrade-results.txt (bảng ca x đẳng thức x cờ).
"""
import importlib.util
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent  # receipt-app/
FLOWS = HERE / "flows"


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


port = load("port", ROOT / "m1fix" / "port.py")
recon = load("reconcile", ROOT / "core-redo" / "reconcile.py")
fixtures = load("fixtures", ROOT / "m1fix" / "fixtures.py")

CONF = 0.9
GT = {
    "001": {"subtotal": 20330, "taxes": [960, 390], "total": 21680, "sold": 15},
    "002": {"subtotal": 20330, "taxes": [960, 390], "total": 21680, "sold": 15},
    "003": {"subtotal": 9691, "taxes": [825], "total": 10516, "sold": None},
}


def base_lines(src):
    if src == "001":
        txt = (ROOT / "parser-prototype" / "sample001-raw-text.txt").read_text(encoding="utf-8")
    elif src == "003":
        txt = (ROOT / "samples" / "sample-003-ocr-raw.txt").read_text(encoding="utf-8")
    elif src == "002":
        return [(t, CONF) for t in fixtures.HEADER_002 + fixtures.ROWS_002]
    else:
        raise ValueError(src)
    return [(t, CONF) for t in txt.splitlines() if t.strip()]


# --- phép biến đổi (thuần text, xác định) ---------------------------------

def tx_replace(lines, old, new, only_if=None):
    out = []
    for t, c in lines:
        if old in t and (only_if is None or only_if in t):
            out.append((t.replace(old, new), c))
        else:
            out.append((t, c))
    return out


def tx_drop(lines, pred):
    return [(t, c) for t, c in lines if not pred(t)]


def tx_split_line(lines, exact, parts):
    out = []
    for t, c in lines:
        if t == exact:
            out.extend((p, c) for p in parts)
        else:
            out.append((t, c))
    return out


def tx_insert_after(lines, anchor_pred, new_lines, before=False):
    out = []
    for t, c in lines:
        if anchor_pred(t) and before:
            out.extend((n, CONF) for n in new_lines)
        out.append((t, c))
        if anchor_pred(t) and not before:
            out.extend((n, CONF) for n in new_lines)
    return out


def tx_move_amount_before_label_003(lines):
    """003: đổi khối tổng từ tiền-trước-nhãn (gốc) sang nhãn-trước-tiền
    ở dòng SUBTOTAL — đối chứng chiều ngược của họ BEFORE."""
    seq = [t for t, _ in lines]
    i_amt = seq.index("96.91")
    i_lab = seq.index("SUBTOTAL")
    out = list(lines)
    amt = out.pop(i_amt)
    lab_idx = [t for t, _ in out].index("SUBTOTAL")
    out.insert(lab_idx + 1, amt)
    return out


def tx_sams_amount_before_label(lines):
    """001: 'SUBTOTAL 203.30' -> hai dòng '203.30' / 'SUBTOTAL'
    (tiền-trước-nhãn áp lên định dạng Sam's)."""
    return tx_split_line(lines, "SUBTOTAL 203.30", ["203.30", "SUBTOTAL"])


def tx_dup_block_003(lines):
    """003: lặp lại nguyên khối món 1 (tiền + mã + tên) như mảnh chồng
    của lát cắt bị dedupe hụt."""
    seq = [t for t, _ in lines]
    block = ["6.98", "52427500021 2 OZ GOR GLU <A>", "GORILLA GLUE 2 OZ"]
    idx = seq.index("GORILLA GLUE 2 OZ")
    out = list(lines)
    for j, b in enumerate(block):
        out.insert(idx + 1 + j, (b, CONF))
    return out


CASES = [
    # mã, họ, nguồn, mô tả, biến đổi
    ("T01", "CTRL", "001", "doi chung nguyen ven 001", lambda l: l),
    ("T02", "CTRL", "003", "doi chung nguyen ven 003 (gom ca BEFORE native)", lambda l: l),
    ("T03", "SPLIT", "001", "xe dong SPRITECANS thanh 2 manh (ten / tien)",
     lambda l: tx_split_line(l, "0980012387 SPRITECANS 19.48 Y",
                             ["0980012387 SPRITE", "CANS 19.48 Y"])),
    ("T04", "SPLIT", "001", "xe dong MM WATER (ma+ten) thanh 2 manh",
     lambda l: tx_split_line(l, "0000561914 MM WATER",
                             ["0000561914 MM", "WATER"])),
    ("T05", "SPLIT", "002", "002 tai dung: xe 'SUBTOTAL 203.30' thanh nhan / tien 2 dong",
     lambda l: tx_split_line(l, "SUBTOTAL 203.30", ["SUBTOTAL", "203.30"])),
    ("T06", "SPLIT", "003", "xe dong ten mon BONA thanh 2 manh",
     lambda l: tx_split_line(l, "BONA HARDWD FLOOR CLEANER 1280Z",
                             ["BONA HARDWD FLOOR", "CLEANER 1280Z"])),
    ("T07", "DROP", "001", "mat 1 dong mon POM TISSUE 26.98",
     lambda l: tx_drop(l, lambda t: "POM TISSUE" in t and "INST" not in t)),
    ("T08", "DROP", "001", "mat dong so luong/tien cua DIETCOK (2 AT ... 38.96)",
     lambda l: tx_drop(l, lambda t: t == "2 AT 1 FOR 19.48 38.96 Y")),
    ("T09", "DROP", "001", "mat dong TAX 2 (3.90)",
     lambda l: tx_drop(l, lambda t: t.startswith("TAX 2"))),
    ("T10", "DROP", "001", "mat dong SUBTOTAL",
     lambda l: tx_drop(l, lambda t: t.startswith("SUBTOTAL"))),
    ("T11", "DROP", "003", "mat dong tien 19.97 cua mon BONA",
     lambda l: tx_drop(l, lambda t: t == "19.97")),
    ("T12", "DROP", "001", "mat ca mon DIETCOK (ten + dong so luong) — mo phong run #26",
     lambda l: tx_drop(l, lambda t: "35PKDIETCOK" in t or t == "2 AT 1 FOR 19.48 38.96 Y")),
    ("T13", "NOISE", "001", "nhieu ky tu token tien GREN: 17.78 -> 17.7B (B=8)",
     lambda l: tx_replace(l, "17.78", "17.7B")),
    ("T14", "NOISE", "001", "nhieu SUBTOTAL: 203.30 -> 2O3.30 (O=0)",
     lambda l: tx_replace(l, "SUBTOTAL 203.30", "SUBTOTAL 2O3.30")),
    ("T15", "NOISE", "001", "mat dau cham thap phan POM TISSUE: 26.98 -> 2698",
     lambda l: tx_replace(l, "26.98", "2698")),
    ("T16", "NOISE", "003", "nhieu TOTAL: $105.16 -> $1O5.16 (O=0)",
     lambda l: tx_replace(l, "$105.16", "$1O5.16")),
    ("T17", "NOISE", "001", "nhieu TAX 1: 9.60 -> 9.6O (O=0)",
     lambda l: tx_replace(l, "9.60", "9.6O")),
    ("T18", "BEFORE", "001", "tien-truoc-nhan tren Sam's: SUBTOTAL tach tien len truoc nhan",
     tx_sams_amount_before_label),
    ("T19", "BEFORE", "003", "doi chung chieu nguoc: SUBTOTAL doi sang nhan-truoc-tien",
     tx_move_amount_before_label_003),
    ("T20", "DUP", "001", "trung nguyen dong SPRITECANS (manh chong lat cat)",
     lambda l: tx_insert_after(l, lambda t: "SPRITECANS" in t, ["0980012387 SPRITECANS 19.48 Y"])),
    ("T21", "DUP", "001", "trung nguyen dong SUBTOTAL (cung gia tri)",
     lambda l: tx_insert_after(l, lambda t: t.startswith("SUBTOTAL"), ["SUBTOTAL 203.30"])),
    ("T22", "DUP", "003", "trung nguyen khoi mon 1 (tien + ma + ten)", tx_dup_block_003),
    ("T23", "GARB", "001", "chen 3 manh rac su co 16:19 len dau luong",
     lambda l: [(g, CONF) for g in ("28200860", "IV Z", "9969080000")] + list(l)),
    ("T24", "GARB", "003", "chen dong rac dang tong gia 'TOTAL 999.99' truoc khoi tong that",
     lambda l: tx_insert_after(l, lambda t: t == "69.96", ["TOTAL 999.99"])),
]

# --- chấm ------------------------------------------------------------------

def evaluate(src, lines):
    gt = GT[src]
    r = port.parse(lines, fixed=True)
    rep, r2 = recon.reconcile(r, lines)
    warns = r["warnings"]
    w_e1 = any("tổng các món" in w for w in warns)
    w_e2 = any("subtotal + thuế" in w for w in warns)
    w_qty = any("Số lượng" in w for w in warns)
    w_total_missing = any("TỔNG TIỀN" in w for w in warns)

    sub2, tot2 = r2["subtotal"], r2["total"]
    taxes2 = sorted(t["amount"] for t in r2["taxes"])
    sum_items = sum(i["amount"] or 0 for i in r2["items"])
    qty_pos = sum(i["qty"] for i in r2["items"] if (i["amount"] or 0) > 0)

    e1_ok = sub2 is not None and abs(sum_items - sub2) <= 2
    e2_ok = (sub2 is not None and tot2 is not None
             and abs(sub2 + sum(taxes2) - tot2) <= 2)
    e3_ok = (gt["sold"] is None) or (r2["itemsSold"] == gt["sold"] and qty_pos == gt["sold"])
    gt_ok = (sub2 == gt["subtotal"] and tot2 == gt["total"]
             and taxes2 == sorted(gt["taxes"]))
    correct = e1_ok and e2_ok and e3_ok and gt_ok

    status = rep["status"]
    flagged_general = status != "OK" or bool(rep.get("requiresReview")) or bool(rep.get("taxMissing"))
    cover = {
        "E1": w_e1 or flagged_general,
        "E2": w_e2 or w_total_missing or flagged_general or bool(rep.get("taxMissing")),
        "E3": w_qty or flagged_general,
        "GT": w_e1 or w_e2 or w_qty or w_total_missing or flagged_general,
    }
    broken = []
    if not e1_ok:
        broken.append("E1")
    if not e2_ok:
        broken.append("E2")
    if not e3_ok:
        broken.append("E3")
    if not gt_ok:
        broken.append("GT")
    silent = [b for b in broken if not cover[b]]

    if correct and (rep["fixes"] or rep.get("requiresReview")):
        verdict = "CORRECT-REPAIRED"
    elif correct:
        verdict = "CORRECT"
    elif silent:
        verdict = "SILENT-WRONG"
    else:
        verdict = "FLAGGED"
    return {
        "verdict": verdict, "status": status, "broken": broken, "silent": silent,
        "sum_items": sum_items, "sub": sub2, "taxes": taxes2, "total": tot2,
        "qty_pos": qty_pos, "sold": r2["itemsSold"], "fixes": len(rep["fixes"]),
        "w_e1": w_e1, "w_e2": w_e2, "w_qty": w_qty,
        "w_total_missing": w_total_missing, "delta": rep.get("delta"),
    }


def main():
    FLOWS.mkdir(exist_ok=True)
    rows = []
    for code, fam, src, desc, fn in CASES:
        lines = fn(base_lines(src))
        (FLOWS / f"{code}.txt").write_text(
            "\n".join(t for t, _ in lines) + "\n", encoding="utf-8")
        ev = evaluate(src, lines)
        rows.append((code, fam, src, desc, ev))
    out = []
    out.append("CỔNG G2 — SUY BIẾN CHỮ (ACCEPTANCE §3.3): ca x đẳng thức x cờ")
    out.append("Bộ máy: m1fix/port.py parse(fixed=True) + core-redo/reconcile.py (T3+T4)")
    out.append("=" * 126)
    hdr = f"{'ca':<4} {'ho':<7} {'nguon':<6} {'verdict':<17} {'recon':<16} {'Σmon':>7} {'sub':>7} {'thue':>13} {'total':>7} {'qty+':>5} {'delta':>7} {'vỡ':<12} cờ:V1/V2/V4/T-"
    out.append(hdr)
    out.append("-" * 126)
    for code, fam, src, desc, ev in rows:
        taxes = "/".join(str(x) for x in ev["taxes"]) or "-"
        flags = (f"{'Y' if ev['w_e1'] else '.'}/{'Y' if ev['w_e2'] else '.'}/"
                 f"{'Y' if ev['w_qty'] else '.'}/{'Y' if ev['w_total_missing'] else '.'}")
        out.append(f"{code:<4} {fam:<7} {src:<6} {ev['verdict']:<17} {ev['status']:<16} "
                   f"{ev['sum_items']:>7} {str(ev['sub']):>7} {taxes:>13} {str(ev['total']):>7} "
                   f"{ev['qty_pos']:>5} {str(ev['delta']):>7} {','.join(ev['broken']) or '-':<12} {flags}"
                   f"  fixes={ev['fixes']}")
        out.append(f"     {desc}")
    n_silent = sum(1 for *_, ev in rows if ev["verdict"] == "SILENT-WRONG")
    n_correct = sum(1 for *_, ev in rows if ev["verdict"].startswith("CORRECT"))
    n_flagged = sum(1 for *_, ev in rows if ev["verdict"] == "FLAGGED")
    out.append("-" * 126)
    out.append("Cột cờ: V1=tổng món≠subtotal · V2=subtotal+thuế≠total · V4=số lượng≠ITEMS SOLD · T-=thiếu TỔNG (validate).")
    out.append("Ca FLAGGED không có cờ validate tương ứng (T10/T14/T18) được bao phủ bởi trạng thái")
    out.append("reconcile TOTAL_ONLY + regionHints đọc-lại vùng tổng — bao phủ ở TẦNG RECONCILE, không phải validate.")
    out.append(f"TỔNG: {len(rows)} ca = {n_correct} CORRECT/CORRECT-REPAIRED + "
               f"{n_flagged} FLAGGED + {n_silent} SILENT-WRONG")
    out.append(f"== G2 GATE: {'PASS' if n_silent == 0 else 'FAIL — có số sai không cờ'} ==")
    text = "\n".join(out) + "\n"
    (HERE / "text-degrade-results.txt").write_text(text, encoding="utf-8")
    print(text)
    return 0 if n_silent == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
