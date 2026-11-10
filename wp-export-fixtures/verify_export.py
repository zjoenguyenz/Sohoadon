# Kiểm WP-EXPORT bản gương: lọc + đặt tên + CSV + ZIP store.
# Fixture: 2 bản ghi metadata THẬT của anh (Sam's 001, Home Depot 003 —
# đáp án ở samples/) + các ca biên tổng hợp ghi rõ SYNTHETIC.
# Byte file gốc là dữ liệu giả lập (kho ảnh thật nằm trên iPhone của anh);
# phép kiểm là về LOGIC, không phải về ảnh thật.
import io
import zipfile
from datetime import date

from export_port import ReceiptRec, build_export, write_zip, money_text, sanitize_vendor

STORE = {
    "sams-001.jpg": b"JPEG-STANDIN-SAMS-001",
    "hd-003.jpg": b"JPEG-STANDIN-HD-003",
    "pho-79.jpg": b"JPEG-STANDIN-PHO79",
    "costco-a.jpg": b"JPEG-STANDIN-COSTCO-A",
    "costco-b.jpg": b"JPEG-STANDIN-COSTCO-B",
    "multi-p1.jpg": b"JPEG-STANDIN-MULTI-P1",
    # multi-p2.jpg CỐ Ý vắng mặt trong store (trang phụ không nạp được)
    "multi-p3.pdf": b"PDF-STANDIN-MULTI-P3",
    "old-2024.jpg": b"JPEG-STANDIN-OLD",
    "edge-from.jpg": b"JPEG-STANDIN-EDGE-FROM",
    "edge-to.pdf": b"PDF-STANDIN-EDGE-TO",
    "nototal.jpg": b"JPEG-STANDIN-NOTOTAL",
    # gone-001.jpg CỐ Ý vắng mặt: tờ có tên file nhưng file không nạp được
}

RECEIPTS = [
    # THẬT — Sam's Club 001 (samples/sample-001-ground-truth.md):
    # Business (thẻ 2586, anh xác nhận), Supplies, thuế = TAX1 9.60 + TAX2 3.90
    ReceiptRec("Sam's Club", date(2026, 10, 29), "business", "Vật Tư",
               20330, 1350, 21680, "2586", ["sams-001.jpg"]),
    # THẬT — Home Depot 003 (samples/sample-003-ground-truth.md):
    # Cá nhân do anh đổi tay (WORK-STATE 12:42), Visa 3830; ảnh gốc đã
    # gắn lại đạt nghiệm 12:53 nên fixture để có file.
    ReceiptRec("The Home Depot", date(2025, 3, 3), "personal", "",
               9691, 825, 10516, "3830", ["hd-003.jpg"]),
    # SYNTHETIC — chưa phân loại + tên có dấu (chỉ vào 'Tất cả')
    ReceiptRec("Quán Phở 79", date(2026, 1, 15), "unknown", "",
               2300, 200, 2500, None, ["pho-79.jpg"]),
    # SYNTHETIC — trùng tên ZIP (cùng ngày/tiệm/tổng)
    ReceiptRec("Costco", date(2026, 5, 1), "business", "Vật Tư",
               4500, 500, 5000, "2586", ["costco-a.jpg"]),
    ReceiptRec("Costco", date(2026, 5, 1), "business", "Vật Tư",
               4500, 500, 5000, "2586", ["costco-b.jpg"]),
    # SYNTHETIC — nhiều trang gốc, trang 2 mất khỏi store
    ReceiptRec("Best Buy", date(2026, 6, 10), "business", "Thiết Bị",
               10000, 850, 10850, "2586",
               ["multi-p1.jpg", "multi-p2.jpg", "multi-p3.pdf"]),
    # SYNTHETIC — ngoài khoảng (trước 2025)
    ReceiptRec("Walmart", date(2024, 12, 31), "business", "Vật Tư",
               900, 100, 1000, "2586", ["old-2024.jpg"]),
    # SYNTHETIC — đúng biên đầu / biên cuối khoảng
    ReceiptRec("Target", date(2025, 10, 1), "business", "Vật Tư",
               1800, 200, 2000, "2586", ["edge-from.jpg"]),
    ReceiptRec("Target", date(2026, 11, 30), "personal", "",
               2700, 300, 3000, "3830", ["edge-to.pdf"]),
    # SYNTHETIC — thiếu tổng (chưa đọc được)
    ReceiptRec("Dollar Tree", date(2026, 2, 2), "personal", "",
               500, None, None, None, ["nototal.jpg"]),
    # SYNTHETIC — có tên file gốc nhưng file không nạp được (ca L-…-5)
    ReceiptRec("Lowe's", date(2026, 4, 4), "business", "Vật Tư",
               7000, 600, 7600, "2586", ["gone-001.jpg"]),
]

results = []
def check(label, cond, detail=""):
    results.append((label, bool(cond), detail))

# --- đơn vị: tiền + làm sạch tên ---
check("U1 money 10516", money_text(10516) == "105.16")
check("U2 money None", money_text(None) == "")
check("U3 money âm", money_text(-500) == "-5.00")
check("U4 Sams", sanitize_vendor("Sam's Club") == "Sams-Club")
check("U5 bỏ dấu", sanitize_vendor("Quán Phở 79") == "Quan-Pho-79")
check("U6 Home Depot", sanitize_vendor("The Home Depot") == "The-Home-Depot")
check("U7 tên rỗng", sanitize_vendor("!!!") == "Khong-ten-tiem")

# --- S1: Business 2025-10-01..2026-11-30 (ví dụ của anh: Business theo khoảng) ---
s1 = build_export(RECEIPTS, STORE, "business", date(2025, 10, 1), date(2026, 11, 30))
names1 = [n for _, fs, _ in s1["entries"] for n, _ in fs]
check("S1 số tờ khớp = 6", s1["summary"]["count"] == 6, str(s1["summary"]))
check("S1 tổng = 21680+5000+5000+10850+2000+7600",
      s1["summary"]["total_cents"] == 52130, str(s1["summary"]["total_cents"]))
check("S1 thiếu gốc = 1 (Lowe's)", s1["summary"]["missing"] == 1)
check("S1 Sam's có mặt", "2026-10-29_Sams-Club_216.80.jpg" in names1, str(names1))
check("S1 trùng tên có -2",
      "2026-05-01_Costco_50.00.jpg" in names1 and
      "2026-05-01_Costco_50.00-2.jpg" in names1, str(names1))
check("S1 đa trang: p1 + trang3 (p2 mất)",
      "2026-06-10_Best-Buy_108.50.jpg" in names1 and
      "2026-06-10_Best-Buy_108.50-trang3.pdf" in names1 and
      not any("trang2" in n for n in names1), str(names1))
check("S1 biên đầu vào, biên cuối là personal nên không vào",
      "2025-10-01_Target_20.00.jpg" in names1)
check("S1 Home Depot (personal) không vào",
      not any("Home-Depot" in n for n in names1))
check("S1 tên ZIP", s1["zip_name"] == "BanGoc-Business-2025-10-01-2026-11-30.zip",
      s1["zip_name"])
csv1 = s1["csv_bytes"].decode("utf-8-sig")
check("S1 CSV có BOM", s1["csv_bytes"].startswith(b"\xef\xbb\xbf"))
check("S1 CSV dòng Lowe's ghi THIẾU BẢN GỐC",
      any("Lowe's" in ln and "THIẾU BẢN GỐC" in ln for ln in csv1.splitlines()))
check("S1 CSV Best Buy ghi thiếu 1 trang gốc",
      any("Best Buy" in ln and "thiếu 1 trang gốc" in ln for ln in csv1.splitlines()))
check("S1 CSV dòng TỔNG", any(ln.startswith(",TỔNG,") and "521.30" in ln
                              for ln in csv1.splitlines()), csv1.splitlines()[-1])

# --- S2: Tất cả theo NĂM 2025 (đường 'theo năm' = 01-01..12-31) ---
s2 = build_export(RECEIPTS, STORE, "all", date(2025, 1, 1), date(2025, 12, 31))
vendors2 = [e[0].vendor for e in s2["entries"]]
check("S2 năm 2025 = 2 tờ (HD + Target biên đầu khoảng năm)",
      s2["summary"]["count"] == 2, str(vendors2))
check("S2 gồm Home Depot + Target 2025-10-01",
      "The Home Depot" in vendors2 and "Target" in vendors2)
check("S2 Walmart 2024 ngoài năm", "Walmart" not in vendors2)

# --- S3: Cá nhân đúng 1 ngày 2025-03-03 (gồm cả hai đầu) ---
s3 = build_export(RECEIPTS, STORE, "personal", date(2025, 3, 3), date(2025, 3, 3))
check("S3 đúng 1 tờ Home Depot", s3["summary"]["count"] == 1 and
      s3["entries"][0][0].vendor == "The Home Depot")
check("S3 tổng 10516", s3["summary"]["total_cents"] == 10516)
check("S3 CSV thẻ 3830 + tổng 105.16",
      "3830" in s3["csv_bytes"].decode("utf-8-sig") and
      "105.16" in s3["csv_bytes"].decode("utf-8-sig"))

# --- S4: Tất cả, khoảng rộng — unknown vào + ghi chú; thiếu tổng ---
s4 = build_export(RECEIPTS, STORE, "all", date(2025, 1, 1), date(2026, 12, 31))
csv4 = s4["csv_bytes"].decode("utf-8-sig")
check("S4 unknown Phở vào Tất cả + ghi chú chưa phân loại",
      any("Quán Phở 79" in ln and "chưa phân loại" in ln for ln in csv4.splitlines()))
check("S4 thiếu gốc toàn cục = 1", s4["summary"]["missing"] == 1,
      str(s4["summary"]))
check("S4 tờ thiếu tổng: tên file chua-doc-duoc-tong",
      any("chua-doc-duoc-tong" in n for _, fs, _ in s4["entries"] for n, _ in fs))
check("S4 Walmart 2024 vẫn ngoài", all(e[0].vendor != "Walmart" for e in s4["entries"]))

# --- S5: ZIP store — cấu trúc + byte thành viên ---
zbytes = write_zip(s1)
z = zipfile.ZipFile(io.BytesIO(zbytes))
check("S5 zip testzip sạch", z.testzip() is None)
check("S5 mọi thành viên STORE", all(i.compress_type == zipfile.ZIP_STORED
                                     for i in z.infolist()))
check("S5 muc-luc.csv là thành viên cuối", z.namelist()[-1] == "muc-luc.csv")
check("S5 csv trong ZIP khớp byte bản sinh",
      z.read("muc-luc.csv") == s1["csv_bytes"])
expect_members = {n: d for _, fs, _ in s1["entries"] for n, d in fs}
check("S5 số thành viên = file gốc + 1 csv",
      len(z.namelist()) == len(expect_members) + 1, str(z.namelist()))
check("S5 byte từng file gốc khớp store",
      all(z.read(n) == d for n, d in expect_members.items()))
check("S5 ZIP tái lập (byte-identical 2 lần chạy)", write_zip(s1) == zbytes)

passed = sum(1 for _, ok, _ in results if ok)
lines = [f"WP-EXPORT verify (bản gương Python) — {passed}/{len(results)} PASS", ""]
for label, ok, detail in results:
    lines.append(f"[{'PASS' if ok else 'FAIL'}] {label}" + (f" — {detail}" if detail and not ok else ""))
with open("verify-export-results.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
print("\n".join(lines))
raise SystemExit(0 if passed == len(results) else 1)
