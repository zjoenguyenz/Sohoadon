#!/usr/bin/env python3
"""Verifier DOC LAP cho dien tap rap lab: chi doc file tren dia,
khong dung loi cua make_rehearsal.py ngoai bang ke dong bang goc.

Nhom kiem:
 1. Catalog dien tap: 69 muc (45 goc + 24 W), 46 muc co file; muc W khop
    Quyet 1/2 (form C, difficulty theo tang, origin lab, gtID rong,
    resourceName dung, statusNote ghi tang goc + LAB/khong GT/khong cong).
 2. Ba phia nhat quan: tap file BenchImages(work) == tap resourceName ==
    tap dong sources project.yml (46); project.yml parse YAML duoc.
 3. Anh W trong work byte-trung staging (sha256 24/24 khop ca staging
    manifest lan subset dong bang).
 4. Ngoac BenchCatalog(work) can bang; appBuild giu nguyen benchapp-2
    (dien tap khong tu nang dau ban — dau ban chi nang o lan rap cuoi co L-R).
 5. benchapp THAT khong bi dung: hash BenchCatalog/project.yml va so
    file BenchImages (22) trung dong #ORIG trong rehearsal-manifest.csv.
 6. Tai lap xac dinh: chay lai make_rehearsal vao thu muc tam -> work
    byte-trung (catalog, project, 46 anh).
 7. Bo cham khong hoi quy: bench_score.py tren selftest app-format ra
    stdout byte-trung file da luu (duong dan tu goc, nhu cac ca truoc).
"""
import csv, hashlib, re, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
WORK = HERE / "work"
BENCHAPP = ROOT / "benchapp"
results = []

def sha256(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()

def check(name, ok, detail=""):
    results.append((name, bool(ok), detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name}  {detail}")

# ---------- 1+2+4: catalog / project / ngoac ----------
cat = (WORK / "BenchCatalog.swift").read_text(encoding="utf-8")
entries = re.findall(
    r'id: "([^"]+)", form: "([^"]+)", difficulty: "([^"]+)", origin: "([^"]+)",\s*\n\s*gtID: "([^"]*)"',
    cat)
by_id = {e[0]: e for e in entries}
with (HERE / "rehearsal-manifest.csv").open(newline="", encoding="utf-8") as f:
    man = [r for r in csv.reader(f)]
hdr, man_rows, orig_rows = man[0], [r for r in man[1:] if r and not r[0].startswith("#")], [r for r in man[1:] if r and r[0].startswith("#")]
w_ok = len(man_rows) == 24
for r in man_rows:
    e = by_id.get(r[0])
    if not e or e[1] != r[2] or e[2] != r[3] or e[3] != "lab" or e[4] != "":
        w_ok = False
# statusNote + resourceName cua tung ca W
note_ok = True
for r in man_rows:
    m = re.search(rf'id: "{r[0]}".*?resourceName: "{r[0]}", pages: nil,\s*\n\s*statusNote: "([^"]*)"\)', cat, re.S)
    if not m or r[1] not in m.group(1) or "LAB" not in m.group(1) or "không GT" not in m.group(1) or "không cổng" not in m.group(1):
        note_ok = False
check("1-catalog-W-khop-quyet", w_ok and note_ok and len(entries) == 69,
      f"tong muc={len(entries)} (ky vong 69); muc W dung Quyet1/2={w_ok}; statusNote={note_ok}")

avail = re.findall(r'resourceName: "([^"]+)"', cat)
files = sorted(p.name for p in (WORK / "BenchImages").glob("*"))
yml_text = (WORK / "project.yml").read_text(encoding="utf-8")
sources = re.findall(r"- BenchImages/(\S+\.jpg)", yml_text)
try:
    import yaml; yaml.safe_load(yml_text); yaml_ok = True
except Exception:
    yaml_ok = False
check("2-ba-phia-46", sorted(f"{a}.jpg" for a in avail) == files == sorted(sources) and len(files) == 46 and yaml_ok,
      f"files={len(files)} resource={len(avail)} sources={len(sources)} yaml_ok={yaml_ok}")

# ---------- 3: anh W byte-trung ----------
with (ROOT / "bench-prep/lab-staging/lab-staging-manifest.csv").open(newline="", encoding="utf-8") as f:
    stg = {r["case_id"]: r for r in csv.DictReader(f)}
with (ROOT / "bench-prep/lab-wildreceipt/wildreceipt-subset.csv").open(newline="", encoding="utf-8") as f:
    sub = {r["case_id"]: r for r in csv.DictReader(f)}
img_ok = all(sha256(WORK / "BenchImages" / f"{c}.jpg") == stg[c]["sha256"] == sub[c]["sha256"] for c in stg)
check("3-anh-W-byte-trung", img_ok and len(stg) == 24, "sha256 work == staging manifest == subset: 24/24" if img_ok else "LECH")

# ---------- 4: ngoac + appBuild ----------
bal = cat.count("{") == cat.count("}") and cat.count("(") == cat.count(")") and cat.count("[") == cat.count("]")
check("4-ngoac+appBuild", bal and 'appBuild = "benchapp-2"' in cat,
      f"{{}} {cat.count('{')}/{cat.count('}')} () {cat.count('(')}/{cat.count(')')} appBuild giu benchapp-2")

# ---------- 5: benchapp that khong bi dung ----------
orig = {r[1]: r[2] for r in orig_rows}
untouched = (sha256(BENCHAPP / "BenchCatalog.swift") == orig.get("BenchCatalog.swift")
             and sha256(BENCHAPP / "project.yml") == orig.get("project.yml")
             and str(len(list((BENCHAPP / "BenchImages").glob("*")))) == orig.get("benchimages_count") == "22")
check("5-benchapp-that-nguyen", untouched, f"hash catalog/project khop #ORIG; BenchImages that = {len(list((BENCHAPP/'BenchImages').glob('*')))} file")

# ---------- 6: tai lap xac dinh ----------
with tempfile.TemporaryDirectory() as td:
    td = Path(td)
    shutil.copy2(HERE / "make_rehearsal.py", td / "make_rehearsal.py")
    # chay ban sao script trong cay tam mo phong: don gian nhat la chay lai script that
    # vao work2 bang cach sao work hien tai ra truoc, chay lai, roi so sanh.
    snap = td / "snap"; shutil.copytree(WORK, snap)
    subprocess.run([sys.executable, str(HERE / "make_rehearsal.py")], capture_output=True, check=True)
    same = all(sha256(snap / p) == sha256(WORK / p) for p in ["BenchCatalog.swift", "project.yml"])
    same = same and sorted(x.name for x in snap.glob("BenchImages/*")) == sorted(x.name for x in WORK.glob("BenchImages/*"))
    same = same and all(sha256(snap / "BenchImages" / x.name) == sha256(WORK / "BenchImages" / x.name) for x in snap.glob("BenchImages/*"))
check("6-tai-lap-byte-trung", same, "chay lai make_rehearsal -> work byte-trung (catalog+project+46 anh)")

# ---------- 7: bo cham khong hoi quy ----------
# bench_score in duong dan dau vao nguyen van o dong 1 -> phai chay dung
# cach cac ca truoc da sinh file da luu: cwd=goc, duong dan tuong doi.
out = subprocess.run([sys.executable, "bench-prep/bench_score.py",
                      "benchapp/selftest/selftest-app-format.json"],
                     capture_output=True, text=True, cwd=ROOT)
saved = (ROOT / "benchapp/selftest/selftest-score-results.txt").read_text(encoding="utf-8")
reg_ok = out.returncode == 0 and out.stdout == saved
check("7-bench-score-hoi-quy", reg_ok, f"exit={out.returncode}; stdout byte-trung file da luu={out.stdout == saved}")

fails = [r for r in results if not r[1]]
print(f"== TONG: {len(results)-len(fails)}/{len(results)} nhom PASS ==")
sys.exit(1 if fails else 0)
