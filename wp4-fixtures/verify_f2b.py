#!/usr/bin/env python3
"""
Kiểm chứng WP4 bước 2 phần F2b (parser chịu tách dòng) — chạy port
f2b_port.py của wp4-prep/Parser.swift trên dòng chữ DỰNG từ đáp án
chuẩn Mẫu 002 + các trường hợp biên. Kết quả: verify-f2b-results.txt.

Bài kiểm:
 S1 Sam's — tổng tách dòng (nhãn một dòng, tiền dòng ngay sau, TAX kèm
    tỉ lệ trên dòng nhãn) -> §F trọn như hàng nguyên.
 S2 Sam's — món tách dòng (mã+tên một dòng, tiền dòng ngay sau; gồm cả
    INST SV tiền âm) -> 10 món, Σ món = subtotal 203.30.
 S3 RÀNG BUỘC hết hạn: nhãn, rồi MỘT dòng chữ xen vào, rồi tiền ->
    tiền KHÔNG được vớ (subtotal vẫn None) — luật 1 dòng ân hạn.
 S4 Nhãn treo cuối hoá đơn không ai hoàn tất -> total vẫn None
    (validate() sẽ gắn cờ như cũ — kỷ luật không đổi).
 S5 HỒI QUY: hàng nguyên 002 (không tách) qua parser có F2b -> §F trọn,
    y hệt kết quả bước 1.
 G1 Generic — tổng tách dòng (SUBTOTAL/SALES TAX/TOTAL) -> đủ 3 số.
 G2 Generic — hết hạn trong vùng SUGGESTED TIP: TOTAL chờ, dòng tip
    xen vào, tiền rời -> total vẫn None.
 G3 Generic — HỒI QUY hàng nguyên (Home Depot cùng-dòng) -> đủ 3 số.
 G4 RANH GIỚI NGUY HIỂM (phát hiện của ca 2026-11-09 22:40): dạng Mẫu
    003 THẬT — tiền ở dòng TRƯỚC, nhãn ở dòng sau (sample-003-ocr-raw.txt)
    -> F2b ghép LỆCH MỘT NHỊP: SUBTOTAL nhận tiền của thuế (825), SALES
    TAX nhận tiền của tổng (10516), TOTAL trống. Build 1 ở dạng này ra
    None cả 3 nên F2b làm dạng này TỆ HƠN (dù sửa đúng dạng nhãn-trước).
    TOTAL trống -> validate() vẫn gắn cờ "Không đọc được TỔNG TIỀN" ->
    tờ vào Hộp Chờ, không sạch lặng lẽ; nhưng 2 số lệch không có cờ
    riêng. Finding bắt buộc: WP7 (chủ dạng tiền-trước-nhãn cho khối
    tổng theo chẩn đoán Mẫu 003) phải xử lý THỨ TỰ khối tổng, hoặc cổng
    WP4 bước 3 phải có quyết riêng cho hazard này. Fixture này khoá
    hành vi thật — cấm kết luận "003 đã khỏi" ở WP4.
"""
import sys

sys.path.insert(0, ".")
from f2b_port import parse_sams, parse_generic_totals  # noqa: E402

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

ITEM_ROWS = ROWS[:15]
TAIL_ROWS = ROWS[19:]  # thẻ / change / items sold / TC#


def L(texts, conf=0.95):
    return [(t, conf) for t in texts]


def section_f(r):
    taxes = sorted(t["amount"] for t in r["taxes"])
    items_sum = sum(i["amount"] or 0 for i in r["items"])
    qty_sum = sum(i["qty"] for i in r["items"] if (i["amount"] or 0) > 0)
    return (r["subtotal"] == 20330 and r["total"] == 21680 and taxes == [390, 960]
            and len(r["items"]) == 10 and items_sum == 20330
            and r["items_sold"] == 15 and qty_sum == 15
            and r["dedupe"] == "SAMS-TC-797797957863725610228")


results = []


def check(name, ok, detail=""):
    results.append((name, ok))
    print(f"[{'PASS' if ok else 'FAIL'}] {name} {detail}")


# S1 — tổng tách dòng
s1 = parse_sams(L(ITEM_ROWS + [
    "SUBTOTAL", "203.30",
    "TAX 1 8.517 %", "9.60",
    "TAX 2 4.017 %", "3.90",
    "TOTAL", "$216.80",
] + TAIL_ROWS))
check("S1 Sam's tổng tách dòng -> §F trọn", section_f(s1),
      f"subtotal={s1['subtotal']} total={s1['total']} taxes={s1['taxes']}")
check("S1 tỉ lệ thuế giữ được từ dòng nhãn",
      [t["rate"] for t in sorted(s1["taxes"], key=lambda x: x["label"])] == ["8.517", "4.017"],
      f"taxes={s1['taxes']}")

# S2 — món tách dòng
s2 = parse_sams(L([
    "0980012382 35PKDIETCOK",
    "2 AT 1 FOR 19.48 38.96 Y",
    "0980012387 SPRITECANS", "19.48 Y",
    "0000806965 DR PEP CANS", "17.28 Y",
    "0000561914 MM WATER",
    "5 AT 1 FOR 4.28 21.40 Y",
    "0000309203 12 OZ BOWL",
    "2 AT 1 FOR 13.98 27.96 T",
    "0000662368 POM TISSUE", "26.98 T",
    "0980143709 13G TRSH LA",
    "2 AT 1 FOR 19.98 39.96 T",
    "0990354068 GREN MM TWE", "17.78 T",
    "INST SV 12 OZ BOWL",
    "2 AT 1 FOR 2.25- 4.50-T",
    "INST SV POM TISSUE", "2.00-T",
] + ROWS[15:19] + TAIL_ROWS))
check("S2 Sam's món tách dòng -> §F trọn", section_f(s2),
      f"items={len(s2['items'])} sum={sum(i['amount'] or 0 for i in s2['items'])}")

# S3 — hết hạn sau 1 dòng xen
s3 = parse_sams(L([
    "SUBTOTAL", "CHANGE DUE 0.00", "203.30", "TOTAL 216.80",
]))
check("S3 nhãn hết hạn: tiền sau dòng xen KHÔNG bị vớ",
      s3["subtotal"] is None and s3["total"] == 21680,
      f"subtotal={s3['subtotal']} total={s3['total']}")

# S4 — nhãn treo không hoàn tất
s4 = parse_sams(L(["SUBTOTAL 203.30", "TOTAL"]))
check("S4 nhãn treo cuối -> total vẫn None (cờ validate giữ nguyên)",
      s4["total"] is None and s4["subtotal"] == 20330,
      f"total={s4['total']}")

# S5 — hồi quy hàng nguyên
s5 = parse_sams(L(ROWS))
check("S5 hồi quy: hàng nguyên 002 -> §F trọn như bước 1", section_f(s5),
      f"subtotal={s5['subtotal']} total={s5['total']}")

# G1 — generic tách dòng
g1 = parse_generic_totals(L([
    "SOME STORE", "SUBTOTAL", "96.91", "SALES TAX", "8.25", "TOTAL", "$105.16",
]))
check("G1 generic tổng tách dòng -> đủ 3 số",
      g1["subtotal"] == 9691 and [t["amount"] for t in g1["taxes"]] == [825]
      and g1["total"] == 10516, f"{g1}")

# G2 — hết hạn trong vùng tip
g2 = parse_generic_totals(L([
    "SOME STORE", "TOTAL", "SUGGESTED TIP", "105.16",
]))
check("G2 generic: TOTAL chờ bị dòng tip làm hết hạn -> total None",
      g2["total"] is None, f"{g2}")

# G3 — generic hồi quy cùng-dòng
g3 = parse_generic_totals(L([
    "THE HOME DEPOT", "SUBTOTAL 96.91", "SALES TAX 8.25", "TOTAL $105.16",
]))
check("G3 generic hồi quy cùng-dòng -> đủ 3 số",
      g3["subtotal"] == 9691 and [t["amount"] for t in g3["taxes"]] == [825]
      and g3["total"] == 10516, f"{g3}")

# G4 — dạng 003 thật: tiền TRƯỚC nhãn -> F2b ghép lệch 1 nhịp (finding)
g4 = parse_generic_totals(L([
    "96.91", "SUBTOTAL", "8.25", "SALES TAX", "$105.16", "TOTAL",
]))
check("G4 HAZARD khoá hành vi thật: ghép lệch (subtotal=825 thuế=10516 total=None)",
      g4["subtotal"] == 825 and [t["amount"] for t in g4["taxes"]] == [10516]
      and g4["total"] is None,
      f"{g4}")

n_pass = sum(1 for _, ok in results if ok)
print(f"\n== {n_pass}/{len(results)} PASS ==")
sys.exit(0 if n_pass == len(results) else 1)
