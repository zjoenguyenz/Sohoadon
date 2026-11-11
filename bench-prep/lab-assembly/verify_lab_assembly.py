# -*- coding: utf-8 -*-
"""Verifier độc lập cho LAB-ASSEMBLY-DECISION.md (ca trực 2026-11-11 12:40).

Không import code của bộ sinh nào; bench_score.py được nạp như một
module để kiểm hàm trọng số và được chạy như tiến trình con để kiểm
hành vi đầu-cuối trên file đo trộn. Mọi kiểm đều đọc từ đĩa.
"""
import csv, importlib.util, json, pathlib, re, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
HERE = pathlib.Path(__file__).resolve().parent
RESULTS = []

def check(name, ok, detail=""):
    RESULTS.append((name, ok, detail))
    return ok

# --- Nhóm 1: ánh xạ 24 ca trong văn bản quyết khớp tầng gốc đóng băng
subset = {}
with open(ROOT / "bench-prep/lab-wildreceipt/wildreceipt-subset.csv",
          encoding="utf-8") as f:
    for row in csv.DictReader(f):
        subset[row["case_id"]] = row["stratum"]
RULE = {"LONG": "L5", "TALL": "L5", "LOWRES": "L4", "DENSE": "L4"}
decision = (HERE / "LAB-ASSEMBLY-DECISION.md").read_text(encoding="utf-8")
# Bảng trong văn bản quyết: mỗi dòng cho (id, tầng gốc, form, difficulty).
# Không neo vào dấu | mở đầu: bảng kê 2 ca/dòng, dấu | cuối của ca trước
# chính là dấu mở của ca sau trên cùng dòng.
rows = re.findall(r"(W-\d+) \| (LONG|DENSE|LOWRES|TALL) \| (.) \| (L\d) \|", decision)
mapped = {r[0]: (r[1], r[2], r[3]) for r in rows}
ok = len(mapped) == 24 and set(mapped) == set(subset)
detail = f"bảng quyết có {len(mapped)}/24 ca"
if ok:
    bad = [cid for cid, (st, form, diff) in mapped.items()
           if subset[cid] != st or form != "C" or RULE[st] != diff]
    ok = not bad
    detail += f"; lệch luật/tầng: {bad or 'không'}"
check("1-anh-xa-24-ca", ok, detail)

# --- Nhóm 2: hàm trọng số của bộ chấm với origin=lab
spec = importlib.util.spec_from_file_location(
    "bench_score", ROOT / "bench-prep" / "bench_score.py")
bs = importlib.util.module_from_spec(spec); spec.loader.exec_module(bs)
diffs = ["L0", "L1", "L2", "L3", "L4", "L5"]
lab_w = all(bs.weight_of({"difficulty": d, "origin": "lab"}) == 1 for d in diffs)
lab_h = all(not bs.is_hard_real({"difficulty": d, "origin": "lab"}) for d in diffs)
reg = (bs.weight_of({"difficulty": "L1", "origin": "real"}) == 2
       and bs.weight_of({"difficulty": "L1", "origin": "synthetic"}) == 1
       and bs.weight_of({"difficulty": "L0", "origin": "real"}) == 1)
check("2-trong-so-lab", lab_w and lab_h and reg,
      f"lab x1 moi difficulty={lab_w}; lab khong phai lop kho that={lab_h}; "
      f"hoi quy real/synthetic={reg}")

# --- Nhóm 3+4: file đo trộn (selftest thật + 2 ca lab dòng rác)
base = json.loads((ROOT / "benchapp/selftest/selftest-app-format.json")
                  .read_text(encoding="utf-8"))
n_cfg = len(base["configs"])
mixed = json.loads(json.dumps(base))
for wid, wdiff in (("W-01", "L5"), ("W-13", "L4")):
    mixed["images"].append({"id": wid, "form": "C", "difficulty": wdiff,
                            "origin": "lab", "gt_id": "",
                            "source_file": "staging", "pages": None,
                            "width_px": 100, "height_px": 100})
    for cfg in base["configs"]:
        mixed["runs"].append({
            "image_id": wid, "config_id": cfg["id"],
            "passes": [{"pass_id": "final", "role": "final",
                        "engine": "vision-classic", "variant": "original",
                        "duration_ms": 1,
                        "lines": [{"text": "999999 rac khong dap an",
                                   "confidence": 0.5, "box": None}]}]})
tmp = pathlib.Path(tempfile.mkdtemp()) / "mixed.json"
tmp.write_text(json.dumps(mixed), encoding="utf-8")

def run_scorer(arg, cwd):
    p = subprocess.run([sys.executable, "bench-prep/bench_score.py", arg],
                       cwd=cwd, capture_output=True, text=True)
    return p.returncode, p.stdout

rc_m, out_m = run_scorer(str(tmp), ROOT)
rc_o, out_o = run_scorer("benchapp/selftest/selftest-app-format.json", ROOT)
expect_lab_line = f"LÀN LAB (origin=lab): {n_cfg * 2} run trên 2 ca"
has_lab = expect_lab_line in out_m
no_err = "không có đáp án" not in out_m and "LỖI DỮ LIỆU ĐO" not in out_m
stripped = "\n".join(l for l in out_m.splitlines()
                     if not l.startswith("-- LÀN LAB"))
same = stripped.replace(str(tmp), "benchapp/selftest/selftest-app-format.json") \
    == out_o.rstrip("\n")
check("3-file-tron-lab", rc_m == 0 and has_lab and no_err,
      f"exit={rc_m}; dong LAN LAB dung so run ({n_cfg * 2})={has_lab}; "
      f"0 loi thieu dap an={no_err}")
check("4-ca-that-khong-doi", rc_o == 0 and same,
      f"bo phan khong-lab cua file tron byte-trung file goc={same}")

# --- Nhóm 5: hồi quy selftest byte-trùng file đã lưu
saved = (ROOT / "benchapp/selftest/selftest-score-results.txt") \
    .read_text(encoding="utf-8")
check("5-hoi-quy-selftest", out_o == saved,
      f"stdout bo cham tren selftest == file da luu: {out_o == saved}")

# --- Nhóm 6: đặc tả + scoresheet nhất quán với quyết
spec_txt = (ROOT / "bench-prep/BENCH-JSON-SPEC.md").read_text(encoding="utf-8")
spec_ok = "`lab`" in spec_txt and "Phiên bản hiện tại: **1**" in spec_txt \
    and "giữ nguyên 1" in spec_txt
with open(ROOT / "bench-prep/measure-pack/scoresheet.csv", encoding="utf-8") as f:
    w_rows = [r for r in csv.DictReader(f) if r["bench_id"].startswith("W-")]
sheet_ok = len(w_rows) == 24 and all(r["origin"] == "lab" for r in w_rows)
check("6-nhat-quan-tai-lieu", spec_ok and sheet_ok,
      f"spec co lab + schema v1={spec_ok}; scoresheet W origin lab "
      f"{sum(1 for r in w_rows if r['origin'] == 'lab')}/24")

passed = sum(1 for _, ok, _ in RESULTS if ok)
lines = [f"{'PASS' if ok else 'FAIL'}  {name}  — {detail}"
         for name, ok, detail in RESULTS]
lines.append(f"== TONG: {passed}/{len(RESULTS)} nhom PASS ==")
out = "\n".join(lines) + "\n"
(HERE / "verify-lab-assembly-results.txt").write_text(out, encoding="utf-8")
print(out, end="")
sys.exit(0 if passed == len(RESULTS) else 1)
