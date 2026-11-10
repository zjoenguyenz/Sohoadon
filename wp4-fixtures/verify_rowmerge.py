#!/usr/bin/env python3
"""
Kiểm chứng WP4 bước 1 (tầng ráp hàng) — wp4-fixtures/verify-results.txt.

Fixture SYNTHETIC dựng từ ĐÁP ÁN CHUẨN Mẫu 002 (samples/sample-002-ground-truth.md):
mỗi hàng thị giác bị xé thành mảnh nhãn + mảnh tiền ĐÚNG NHƯ khiếm khuyết
thực địa Build 1 mô tả (cột tiền tách hẳn bên phải). Toạ độ hộp là dựng
mô phỏng (hàng đều, tiền lệch Y nhẹ 0.002) — kiểm THUẬT TOÁN ráp, không
kiểm Vision. Nguồn tiền/số lấy nguyên văn từ ground truth đã kiểm số học.

Bài kiểm:
 A. mergeRows trên mảnh xé -> 24 hàng khớp ground truth (chuẩn hoá khoảng trắng).
 B. Hàng ráp đưa vào parser Sam's (parser-prototype/parse_receipt.py) -> §F:
    subtotal 203.30 · thuế 9.60+3.90 · total 216.80 · 10 dòng món · Σ món
    203.30 · 15 món · khoá TC# đủ 21 số.
 C. dedupeOverlap: chèn mảnh trùng vùng chồng (lệch Y 0.004, confidence
    thấp hơn) -> số mảnh sau khử = số mảnh gốc, hàng ráp không đổi.
 D. Đối chứng âm (hành vi Build 1): mảnh phát 1:1 không ráp -> parser §F TRƯỢT
    (chứng minh fixture có răng: không ráp thì mất tiền thật).
 E. Biên: mảnh chồng Y < 50% KHÔNG được ráp (dòng kề riêng); 3 mảnh 1 hàng
    sắp đúng trái->phải bất kể thứ tự vào.
"""
import re
import sys

sys.path.insert(0, ".")
sys.path.insert(0, "../parser-prototype")
from rowmerge_port import Frag, dedupe_overlap, merge_rows  # noqa: E402
from parse_receipt import parse  # noqa: E402

ROWS = [
    "0980012382 35PKDIETCOK",
    "2 AT 1 FOR 19.48 38.96 Y",
    "0980012387 SPRITECANS 19.48 Y",
    "0000806965 DR PEP CANS 17.28 Y",
    "0000561914 MM WATER",
    "5 AT 1 FOR 4.28 21.40 Y",
    "0000309203 12 OZ BOWL",
    "2 AT 1 FOR 13.98 27.96 T",
    "0000662368 POM TISSUE 26.98 T",
    "0980143709 13G TRSH LA",
    "2 AT 1 FOR 19.98 39.96 T",
    "0990354068 GREN MM TWE 17.78 T",
    "INST SV 12 OZ BOWL",
    "2 AT 1 FOR 2.25- 4.50-T",
    "INST SV POM TISSUE 2.00-T",
    "SUBTOTAL 203.30",
    "TAX 1 8.517 % 9.60",
    "TAX 2 4.017 % 3.90",
    "TOTAL 216.80",
    "MASTERCARD DEBIT TEND 216.80",
    "MASTERCARD **** **** **** 2586",
    "CHANGE DUE 0.00",
    "# ITEMS SOLD 15",
    "TC# 7977 9795 7863 7256 1022 8",
]
AMOUNT_TAIL = re.compile(r"^(.+?)\s+(\d+\.\d{2}-?(?:\s*[YT])?|\d+\.\d{2}-)$")


def make_frags():
    """Xé mỗi hàng thành mảnh nhãn (trái) + mảnh tiền (phải, lệch Y -0.002)."""
    frags = []
    n = len(ROWS)
    rh = 1.0 / n
    for i, row in enumerate(ROWS):
        maxy = 1.0 - i * rh - 0.006          # gốc dưới-trái: hàng 0 ở đỉnh
        miny = maxy - 0.030
        m = AMOUNT_TAIL.match(row)
        if m and not row.startswith(("MASTERCARD ****", "TC#")):
            label, amount = m.group(1), m.group(2)
            frags.append(Frag(label, 0.95, 0.02, miny, 0.02 + 0.011 * len(label), maxy))
            frags.append(Frag(amount, 0.90, 0.80, miny - 0.002, 0.80 + 0.011 * len(amount), maxy - 0.002))
        else:
            frags.append(Frag(row, 0.95, 0.02, miny, 0.02 + 0.011 * len(row), maxy))
    return frags


def norm(s):
    return re.sub(r"\s+", " ", s).strip()


results = []
def check(name, ok, detail=""):
    results.append((name, ok, detail))
    print(f"[{'PASS' if ok else 'FAIL'}] {name} {detail}")


frags = make_frags()

# A
lines = merge_rows(dedupe_overlap(frags))
texts = [t for t, _ in lines]
check("A merge=24 hàng", len(texts) == 24, f"got {len(texts)}")
check("A hàng khớp ground truth", [norm(t) for t in texts] == [norm(r) for r in ROWS])

# B
r = parse("\n".join(texts))
taxes = sorted(str(t["amount"]) for t in r["taxes"])
ok_f = (str(r["subtotal"]) == "203.30" and str(r["total"]) == "216.80" and taxes == ["3.90", "9.60"]
        and len(r["items"]) == 10 and str(r["validation"]["items_sum"]) == "203.30"
        and r["items_sold"] == 15 and r["tc_number"] == "797797957863725610228")
check("B §F qua parser trên hàng ráp", ok_f,
      f"subtotal={r['subtotal']} total={r['total']} taxes={taxes} items={len(r['items'])} sold={r['items_sold']} tc={r.get('tc_number')} val={r.get('validation')}")

# C
dupes = []
for f in frags[:6]:
    dupes.append(Frag(f.text, 0.50, f.minx, f.miny - 0.004, f.maxx, f.maxy - 0.004))
after = dedupe_overlap(frags + dupes)
check("C dedupe bỏ đúng 6 mảnh trùng", len(after) == len(frags), f"{len(frags)+6} -> {len(after)}")
check("C hàng ráp sau dedupe không đổi", [t for t, _ in merge_rows(after)] == texts)

# D — Build 1: mảnh 1:1, sắp maxY giảm dần, không ráp
b1 = [f.text for f in sorted(frags, key=lambda x: -x.maxy)]
r1 = parse("\n".join(b1))
check("D đối chứng âm: không ráp thì §F trượt", not (r1.get("subtotal") == "203.30" and r1.get("total") == "216.80"),
      f"subtotal={r1.get('subtotal')} total={r1.get('total')} items={len(r1.get('items', []))}")

# E
edge = [Frag("DONG TREN", 0.9, 0.02, 0.80, 0.30, 0.83),
        Frag("DONG DUOI", 0.9, 0.02, 0.775, 0.30, 0.79)]  # chồng 0.01/0.03 = 33% < 50%
check("E chồng <50% không ráp", len(merge_rows(edge)) == 2)
tri = [Frag("C", 0.9, 0.70, 0.50, 0.80, 0.53),
       Frag("A", 0.9, 0.02, 0.50, 0.20, 0.53),
       Frag("B", 0.9, 0.30, 0.50, 0.50, 0.53)]
check("E 3 mảnh 1 hàng sắp trái->phải", merge_rows(tri)[0][0] == "A B C")
check("E confidence dòng ráp = min mảnh", abs(merge_rows(tri)[0][1] - 0.9) < 1e-9)

n_pass = sum(1 for _, ok, _ in results if ok)
print(f"\n== {n_pass}/{len(results)} PASS ==")
sys.exit(0 if n_pass == len(results) else 1)
