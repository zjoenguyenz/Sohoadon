#!/usr/bin/env python3
"""Verifier DOC LAP cho dien tap rap L-R + nang dau ban: chi doc file
tren dia, doi chieu voi bang input dong bang + cac nguon dong bang
goc (bench_score ANSWERS, benchapp that, nen dien tap lab).

Nhom kiem:
 1. Catalog ban sao: 10 muc L-R khop bang input tung truong (form/
    difficulty/gtID/resourceName/sourceFile/pages), statusNote khong
    con "THIEU", co ghi DIEN TAP + ten anh dung thay.
 2. Ba phia nhat quan: file BenchImages(work) == resourceName ==
    sources project.yml (56); tong muc catalog 69; YAML parse OK.
 3. Anh L-R trong work byte-trung anh dung thay o benchapp that:
    sha256 10/10 khop bang input.
 4. Ngoac can bang; appBuild ban sao = benchapp-3; 24 muc W (lab)
    nguyen ven (origin lab = 24).
 5. benchapp THAT khong bi dung: hash catalog/project + so anh (22)
    khop #ORIG; khong co file L-R*.jpg o BenchImages that; appBuild
    that van benchapp-2; nen dien tap lab khong bi dung (hash #ORIG).
 6. Tai lap xac dinh: chay lai make -> work byte-trung.
 7. Hoi quy bo cham: bench_score.py tren selftest app-format stdout
    byte-trung file da luu (cwd=goc + duong dan tuong doi).
 8. gt_id dung trong dien tap deu co that trong ANSWERS cua
    bench_score.py (bo cham tim thay dap an ma khong can --answers).
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
    results.append((name, bool(ok)))
    print(f"{'PASS' if ok else 'FAIL'}  {name}  {detail}")

# ---------- bang input + manifest ----------
with (HERE / "lr-rehearsal-input.csv").open(newline="", encoding="utf-8") as f:
    inp = list(csv.DictReader(f))
with (HERE / "lr-rehearsal-manifest.csv").open(newline="", encoding="utf-8") as f:
    man = [r for r in csv.reader(f) if r]
orig = {r[1]: r[2] for r in man[1:] if r[0].startswith("#")}

cat = (WORK / "BenchCatalog.swift").read_text(encoding="utf-8")

# ---------- 1: muc L-R khop input ----------
lr_ok, note_ok = True, True
for r in inp:
    lid = r["lr_id"]
    m = re.search(
        rf'id: "{lid}", form: "([^"]+)", difficulty: "([^"]+)", origin: "real",\s*\n'
        rf'\s*gtID: "([^"]*)",\s*\n\s*sourceFile: "([^"]*)",\s*\n'
        rf'\s*resourceName: "{lid}", pages: ([^,]+),\s*\n\s*statusNote: "([^"]*)"\)', cat)
    if not m:
        lr_ok = False; continue
    pages = r["pages"] if r["pages"] else "nil"
    if (m.group(1), m.group(2), m.group(3)) != (r["form"], r["difficulty"], r["gt_id"]):
        lr_ok = False
    if m.group(4) != f'REHEARSAL-STANDIN-{r["standin_file"]}' or m.group(5) != pages:
        lr_ok = False
    if "THIẾU" in m.group(6) or "DIỄN TẬP" not in m.group(6) or r["standin_file"] not in m.group(6):
        note_ok = False
check("1-catalog-LR-khop-input", lr_ok and note_ok, f"10 muc L-R tung truong={lr_ok}; statusNote dien tap/khong-THIEU={note_ok}")

# ---------- 2: ba phia 56 ----------
entries = re.findall(r'id: "([^"]+)", form:', cat)
avail = re.findall(r'resourceName: "([^"]+)"', cat)
files = sorted(p.name for p in (WORK / "BenchImages").glob("*"))
yml_text = (WORK / "project.yml").read_text(encoding="utf-8")
sources = re.findall(r"- BenchImages/(\S+\.jpg)", yml_text)
try:
    import yaml; yaml.safe_load(yml_text); yaml_ok = True
except Exception:
    yaml_ok = False
check("2-ba-phia-56", sorted(f"{a}.jpg" for a in avail) == files == sorted(sources) and len(files) == 56 and len(entries) == 69 and yaml_ok,
      f"tong muc={len(entries)} files={len(files)} resource={len(avail)} sources={len(sources)} yaml_ok={yaml_ok}")

# ---------- 3: anh L-R byte-trung ----------
img_ok = all(sha256(WORK / "BenchImages" / f'{r["lr_id"]}.jpg') == r["sha256"] == sha256(BENCHAPP / "BenchImages" / r["standin_file"]) for r in inp)
check("3-anh-LR-byte-trung", img_ok, "sha256 work == bang input == anh dung thay that: 10/10" if img_ok else "LECH")

# ---------- 4: ngoac + appBuild + W nguyen ----------
bal = cat.count("{") == cat.count("}") and cat.count("(") == cat.count(")") and cat.count("[") == cat.count("]")
check("4-ngoac+appBuild+W", bal and 'appBuild = "benchapp-3"' in cat and cat.count('origin: "lab"') == 24,
      f"{{}} {cat.count('{')}/{cat.count('}')} () {cat.count('(')}/{cat.count(')')} appBuild=benchapp-3 (ban sao); muc lab={cat.count(chr(34).join(['origin: ', 'lab', ''])) if False else cat.count('origin: ' + chr(34) + 'lab' + chr(34))}")

# ---------- 5: benchapp that + nen lab nguyen ----------
real_files = list((BENCHAPP / "BenchImages").glob("*"))
real_cat = (BENCHAPP / "BenchCatalog.swift").read_text(encoding="utf-8")
base = ROOT / "bench-prep" / "lab-assembly" / "rehearsal" / "work"
untouched = (sha256(BENCHAPP / "BenchCatalog.swift") == orig.get("BenchCatalog.swift")
             and sha256(BENCHAPP / "project.yml") == orig.get("project.yml")
             and str(len(real_files)) == orig.get("benchimages_count") == "22"
             and not list((BENCHAPP / "BenchImages").glob("L-R*.jpg"))
             and 'appBuild = "benchapp-2"' in real_cat
             and sha256(base / "BenchCatalog.swift") == orig.get("base_catalog_sha256")
             and sha256(base / "project.yml") == orig.get("base_project_sha256"))
check("5-benchapp-that+nen-lab-nguyen", untouched, f"BenchImages that={len(real_files)} file, 0 file L-R, appBuild that=benchapp-2, hash nen lab khop #ORIG")

# ---------- 6: tai lap ----------
with tempfile.TemporaryDirectory() as td:
    snap = Path(td) / "snap"; shutil.copytree(WORK, snap)
    subprocess.run([sys.executable, str(HERE / "make_lr_rehearsal.py")], capture_output=True, check=True)
    same = all(sha256(snap / p) == sha256(WORK / p) for p in ["BenchCatalog.swift", "project.yml"])
    same = same and sorted(x.name for x in snap.glob("BenchImages/*")) == sorted(x.name for x in WORK.glob("BenchImages/*"))
    same = same and all(sha256(snap / "BenchImages" / x.name) == sha256(WORK / "BenchImages" / x.name) for x in snap.glob("BenchImages/*"))
check("6-tai-lap-byte-trung", same, "chay lai make_lr_rehearsal -> work byte-trung (catalog+project+56 anh)")

# ---------- 7: bo cham hoi quy ----------
out = subprocess.run([sys.executable, "bench-prep/bench_score.py",
                      "benchapp/selftest/selftest-app-format.json"],
                     capture_output=True, text=True, cwd=ROOT)
saved = (ROOT / "benchapp/selftest/selftest-score-results.txt").read_text(encoding="utf-8")
check("7-bench-score-hoi-quy", out.returncode == 0 and out.stdout == saved,
      f"exit={out.returncode}; stdout byte-trung file da luu={out.stdout == saved}")

# ---------- 8: gt co trong ANSWERS ----------
score_src = (ROOT / "bench-prep" / "bench_score.py").read_text(encoding="utf-8")
answers_block = score_src.split("ANSWERS = {", 1)[1].split("\n}", 1)[0] if "ANSWERS = {" in score_src else ""
known_gt = set(re.findall(r'"(GT-[^"]+)":', answers_block))
gt_ok = {r["gt_id"] for r in inp} <= known_gt
check("8-gt-co-trong-ANSWERS", gt_ok, f"gt dien tap {sorted({r['gt_id'] for r in inp})} <= ANSWERS {sorted(known_gt)}")

fails = [r for r in results if not r[1]]
print(f"== TONG: {len(results)-len(fails)}/{len(results)} nhom PASS ==")
sys.exit(1 if fails else 0)
