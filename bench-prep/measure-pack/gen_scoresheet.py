# -*- coding: utf-8 -*-
"""SINH BẢNG CHẤM ĐÓNG BĂNG (scoresheet.csv) cho BUỔI ĐO DUY NHẤT.

Xác định hoàn toàn (không random, không đồng hồ): đọc
  - benchapp/BenchCatalog.swift      (45 mục: 22 có file + 23 THIẾU)
  - bench-prep/lab-wildreceipt/wildreceipt-subset.csv  (24 ca W)
rồi cộng 2 ca kiểm dữ liệu đã lưu L-01/L-02 của ACCEPTANCE §4.2 Phần 5
(không thuộc catalog BenchApp — chạy trong app chính).

Mỗi dòng = 1 ca: phần buổi đo + mã buổi đo + hồ sơ ngưỡng (theo
ACCEPTANCE §2.3) + đường chấm (bench_score.py / tại-bảng / chờ đáp án).
Ngưỡng KHÔNG nằm trong file này — hồ sơ ngưỡng trỏ về ACCEPTANCE §2.3
trong MEASURE-PACK.md; file CSV chỉ khoá ÁNH XẠ ca → hồ sơ, để buổi đo
không ai tự chọn ngưỡng giữa chừng.
"""
import csv, io, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CATALOG = ROOT / "benchapp" / "BenchCatalog.swift"
WILD = ROOT / "bench-prep" / "lab-wildreceipt" / "wildreceipt-subset.csv"
OUT = pathlib.Path(__file__).resolve().parent / "scoresheet.csv"

HEADER = ["session_part", "session_code", "bench_id", "form", "difficulty",
          "origin", "status", "gt_or_reference", "scoring_route",
          "threshold_profile", "m9_rule", "notes"]

M9 = "M9=0: so sai khong co = rot toan bo ban (ACCEPTANCE 2.4.1)"

# Ánh xạ mã buổi đo ACCEPTANCE §4.2 ↔ mã BenchCatalog (ghi rõ trong
# MEASURE-PACK.md mục 2; S-0 là ca cổng danh dự của BENCH-MANIFEST §2,
# §4.2 Phần 1 chỉ liệt kê 4 dòng nên S-0 đứng dòng 5 của Phần 1).
PART1 = {"N-001": "S-01", "N-002": "S-02", "C-002C": "S-03",
         "C-003": "S-04", "S-0": "S-05-HONOR"}

def profile_for(bid, origin, gt):
    if origin == "synthetic":
        return "D"
    if bid == "N-001" or bid == "C-002C":
        return "A"
    if bid == "N-002":
        return "B"
    if bid in ("C-003", "S-1"):
        return "C-SEED"
    if bid == "S-0":
        return "S0-HONOR"
    if bid == "PDF-SAM":
        return "PDF"
    return "C-REAL"  # ca thật mở rộng + ô L-R (tạm khoá; chốt lại khi phân loại)

def route_for(bid, status, gt):
    if bid == "PDF-SAM":
        return "ngoai-bench (duong WP3)"
    if gt in ("GT-SAMS-F", "GT-HD-003"):
        return "bench_score.py" if status == "READY" else "bench_score.py (khi co anh; dap an da dong bang)"
    if status in ("EMPTY-SLOT", "MISSING"):
        return "cho-dap-an (bench_score.py --answers khi dong bang)"
    return "tai-bang"

# Ghi chú riêng cho các ô THIẾU có cách lấp khác đường nạp L-R.
MISSING_NOTES = {
    "C-002C": "Chup thuong chinh to Sam's giay o buoi chuan bi; duong camera trong app la diem kiem rieng",
    "S-1": "Quet (VNDocumentCamera) to Home Depot o buoi chuan bi — cap voi C-003 de tach bien so DANG khoi noi dung",
    "S-2": "Quet mot to nhan THAT tu kho cua anh o buoi chuan bi; dap an dong bang sau khi chep tay",
    "PDF-SAM": "Cho file PDF Sam's that khi anh tai duoc; BenchApp ban nay chi do anh",
}

def part_for(bid):
    if bid in PART1:
        return ("1-HAT-GIONG", PART1[bid])
    if bid.startswith("D-"):
        return ("3-SUY-BIEN-ANH", bid)
    if bid.startswith("L-R"):
        n = int(bid[3:])
        return ("2-CA-THAT", f"C-{n:02d}")
    # Các ô THIẾU cũ của BENCH-MANIFEST §3 = danh sách mong muốn mà
    # đường nạp L-R01..10 thực hiện; giữ nguyên mã của chúng ở Phần 2.
    return ("2-CA-THAT", bid)

def parse_catalog(text):
    blocks = re.findall(r"BenchImageDefinition\((.*?)\)", text, re.S)
    rows = []
    for b in blocks:
        def f(key, default=""):
            m = re.search(rf'{key}:\s*"([^"]*)"', b)
            if m:
                return m.group(1)
            m = re.search(rf"{key}:\s*nil", b)
            return default if m else default
        bid = f("id")
        res = re.search(r'resourceName:\s*"([^"]*)"', b)
        rows.append({
            "id": bid, "form": f("form"), "difficulty": f("difficulty"),
            "origin": f("origin"), "gt": f("gtID"),
            "status": "READY" if res else (
                "EMPTY-SLOT" if bid.startswith("L-R") else "MISSING"),
        })
    return rows

def main():
    cat = parse_catalog(CATALOG.read_text(encoding="utf-8"))
    assert len(cat) == 45, f"catalog co {len(cat)} muc, ky vong 45"
    out = []
    for c in cat:
        part, code = part_for(c["id"])
        prof = profile_for(c["id"], c["origin"], c["gt"])
        note = ""
        if c["id"] == "S-0":
            note = "Ca cong danh du: truot tron bo F o cau hinh giai phap = loai cau hinh tai cho"
        if c["status"] == "EMPTY-SLOT":
            note = "O trong cho anh that; ho so nguong tam khoa C-REAL, Leader chot lai khi phan loai + dong bang gt"
        if c["status"] == "MISSING" and not c["id"].startswith("L-R"):
            note = MISSING_NOTES.get(
                c["id"],
                "O mong muon BENCH-MANIFEST muc 3; duong nap thuc te la L-R01..10 (muc 3.1)")
        out.append([part, code, c["id"], c["form"], c["difficulty"],
                    c["origin"], c["status"], c["gt"] or "-",
                    route_for(c["id"], c["status"], c["gt"]), prof, M9, note])
    wild_ids = []
    with WILD.open(encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            wild_ids.append(r["case_id"])
    assert len(wild_ids) == 24, f"wild co {len(wild_ids)} ca, ky vong 24"
    for wid in wild_ids:
        out.append(["3B-LAN-LAB", wid, wid, "-", "-", "lab", "NOT-EMBEDDED",
                    "nhan WildReceipt nguyen van (wildreceipt-subset.csv)",
                    "tai-bang",
                    "LAB", M9,
                    "M1/M2 dung-hoac-co doi chieu nhan nguyen van + E1/E2 dang thuc NOI BO; khong bao gio trinh nhu so mon ngoai; chua nhung BenchApp — rap o ban bench cuoi"])
    out.append(["5-DU-LIEU-DA-LUU", "L-01", "L-01", "-", "-", "real",
                "SESSION-CHECK", "GT-HD-003 (to Home Depot da luu Build 1)",
                "tai-bang (anh chup buoi do)", "SAVED", M9,
                "Mo to da luu -> Doc lai -> so dung + ten/dia chi dung + anh goc hien thi duoc (B2 Dieu 1b, 3 thanh phan)"])
    out.append(["5-DU-LIEU-DA-LUU", "L-02", "L-02", "-", "-", "real",
                "SESSION-CHECK", "2 to cu trong kho cua anh",
                "tai-bang (anh chup buoi do)", "SAVED", M9,
                "Dong app/mo lai sau cai de: 2 to cu con nguyen, so khong doi (B2 Dieu 1a)"])
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\n")
    w.writerow(HEADER)
    w.writerows(out)
    data = buf.getvalue()
    if "--stdout" in sys.argv:
        sys.stdout.write(data)
    else:
        OUT.write_text(data, encoding="utf-8")
        print(f"da ghi {OUT} — {len(out)} dong ca + header")

if __name__ == "__main__":
    main()
