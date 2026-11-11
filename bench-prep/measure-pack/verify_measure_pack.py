# -*- coding: utf-8 -*-
"""VERIFIER ĐỘC LẬP cho gói đo đóng băng (không import gen_scoresheet).

Đọc lại từ đĩa: BenchCatalog.swift · wildreceipt-subset.csv ·
bench_score.py (sổ đáp án) · scoresheet.csv · MEASURE-PACK.md.
Chạy: python3 verify_measure_pack.py  → ghi verify-measure-pack-results.txt
"""
import csv, pathlib, re, subprocess, sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = HERE / "verify-measure-pack-results.txt"
lines, fails = [], []

def check(name, ok, detail=""):
    lines.append(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" — {detail}" if detail else ""))
    if not ok:
        fails.append(name)

sheet_path = HERE / "scoresheet.csv"
rows = list(csv.DictReader(sheet_path.open(encoding="utf-8")))
hdr = sheet_path.read_text(encoding="utf-8").splitlines()[0]

# 1. Cấu trúc bảng
check("1-header+71-dong", hdr.startswith("session_part,session_code,bench_id")
      and len(rows) == 71, f"rows={len(rows)}")

# 2. Tập mã catalog khớp BenchCatalog.swift
cat_text = (ROOT / "benchapp" / "BenchCatalog.swift").read_text(encoding="utf-8")
cat_ids = re.findall(r'BenchImageDefinition\(\s*\n?\s*id:\s*"([^"]+)"', cat_text)
if len(cat_ids) != 45:
    cat_ids = re.findall(r'id:\s*"([A-Z][A-Z0-9\-]+)"', cat_text)
sheet_cat = [r for r in rows if r["bench_id"] not in
             {f"W-{i:02d}" for i in range(1, 25)} | {"L-01", "L-02"}]
check("2-tap-ma-catalog-45", sorted(r["bench_id"] for r in sheet_cat) == sorted(set(cat_ids)),
      f"catalog={len(set(cat_ids))} sheet={len(sheet_cat)}")

# 3. Đếm trạng thái
from collections import Counter
st = Counter(r["status"] for r in rows)
check("3-trang-thai", st == Counter({"READY": 22, "MISSING": 13, "EMPTY-SLOT": 10,
      "NOT-EMBEDDED": 24, "SESSION-CHECK": 2}), str(dict(st)))

# 4. Ca READY mang GT có thật trong sổ đáp án bench_score.py
score_text = (ROOT / "bench-prep" / "bench_score.py").read_text(encoding="utf-8")
answers = set(re.findall(r'"(GT-[A-Z0-9\-]+)":\s*\{', score_text))
bad = [r["bench_id"] for r in rows if r["status"] == "READY"
       and r["gt_or_reference"] not in answers]
check("4-ready-gt-that", not bad, f"answers={sorted(answers)} bad={bad}")

# 5. Synthetic: hồ sơ D + origin synthetic + chấm bằng bench_score
syn = [r for r in rows if r["origin"] == "synthetic"]
check("5-synthetic-18-D", len(syn) == 18 and all(
    r["threshold_profile"] == "D" and r["scoring_route"] == "bench_score.py"
    and r["status"] == "READY" for r in syn), f"n={len(syn)}")

# 6. Làn lab khớp wildreceipt-subset.csv
wild = [r["case_id"] for r in csv.DictReader(
    (ROOT / "bench-prep" / "lab-wildreceipt" / "wildreceipt-subset.csv").open(encoding="utf-8"))]
wrows = [r for r in rows if r["threshold_profile"] == "LAB"]
check("6-lab-24", sorted(r["bench_id"] for r in wrows) == sorted(wild)
      and all(r["status"] == "NOT-EMBEDDED" for r in wrows), f"n={len(wrows)}")

# 7. Luật M9 trên mọi dòng + hồ sơ/mã hợp lệ
valid_prof = {"A", "B", "C-SEED", "C-REAL", "D", "LAB", "S0-HONOR", "SAVED", "PDF"}
check("7-m9+ho-so", all(r["m9_rule"].startswith("M9=0") for r in rows)
      and all(r["threshold_profile"] in valid_prof for r in rows)
      and len({r["bench_id"] for r in rows}) == 71, "71/71 dong co luat M9, 0 trung ma")

# 8. Ánh xạ mã buổi đo Phần 1 + Phần 2
m = {r["bench_id"]: r["session_code"] for r in rows}
check("8-anh-xa-ma", m.get("N-001") == "S-01" and m.get("N-002") == "S-02"
      and m.get("C-002C") == "S-03" and m.get("C-003") == "S-04"
      and m.get("S-0") == "S-05-HONOR"
      and all(m.get(f"L-R{i:02d}") == f"C-{i:02d}" for i in range(1, 11)), "")

# 9. Sinh lại byte-trùng
regen = subprocess.run([sys.executable, str(HERE / "gen_scoresheet.py"), "--stdout"],
                       capture_output=True, text=True)
check("9-tai-lap-byte-trung", regen.stdout == sheet_path.read_text(encoding="utf-8"),
      f"rc={regen.returncode}")

# 10. MEASURE-PACK.md chứa số đóng băng + ghi rõ điều kiện còn chặn
md = (HERE / "MEASURE-PACK.md").read_text(encoding="utf-8")
need = ["203.30", "216.80", "105.16", "96.91", "M9 > 0", "benchapp-2",
        "CHƯA CÓ", "S-05-DANH-DỰ", "B-04", "L-01"]
missing = [s for s in need if s not in md]
check("10-md-so-dong-bang+chan", not missing, f"thieu={missing}")

verdict = "PASS" if not fails else f"FAIL ({len(fails)} nhom: {fails})"
lines.append(f"\nKET LUAN: {verdict} — {10 - len(fails)}/10 nhom PASS")
OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
print("\n".join(lines))
sys.exit(0 if not fails else 1)
