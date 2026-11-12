#!/usr/bin/env python3
"""DIEN TAP RAP L-R + NANG DAU BAN — ap quy uoc nap 5 buoc o
benchapp/AFTER.md (muc BENCH-CATALOG-EXT) + nang appBuild len MOT
BAN SAO CACH LY, KHONG dung benchapp/ that va KHONG dung ca ban
sao dien tap lab (chi doc no lam nen).

Nen (base): bench-prep/lab-assembly/rehearsal/work/ — catalog 69 muc
(45 goc + 24 W), 46 anh, appBuild benchapp-2. Day la dung trang thai
ma lan rap cuoi se dung: lab da rap, L-R sap lap.

Anh dung-thay (stand-in): 10 anh hat giong DA CO trong benchapp/
BenchImages (4 that + 6 synthetic), gan vao o L-R01..L-R10 theo bang
dong bang lr-rehearsal-input.csv (form/difficulty/gt lay theo dung ca
hat giong nguon — KHONG bia phan loai, KHONG bia dap an; gt tai dung
GT-SAMS-F / GT-HD-003 da dong bang trong bench_score.py).
statusNote cua ban sao ghi ro "DIEN TAP — anh dung thay" de khong
ai doc nham thanh ca that.

5 buoc AFTER.md ap cho tung o L-Rnn:
 1. chep anh -> work/BenchImages/L-Rnn.jpg (sha truoc/sau khop input)
 2. dien catalog: resourceName "L-Rnn" + sourceFile = nhan dung thay
    + pages neu co
 3. them 1 dong sources vao project.yml (sau dong W-24)
 4. dien form/difficulty/gtID theo bang input (= phan loai + dap an
    dong bang cua Leader o lan that)
 5. statusNote doi tu "THIEU — ..." sang mo ta san sang (dien tap)
Cong: appBuild benchapp-2 -> benchapp-3 CHI o ban sao (lan rap cuoi
nang dau ban that; dien tap chung minh thao tac co hoc nay sach).

Dau ra: rehearsal/work/ (BenchCatalog.swift, project.yml,
BenchImages/ 56 file) + lr-rehearsal-manifest.csv. Xac dinh.
"""
import csv, hashlib, re, shutil, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]          # receipt-app/
HERE = Path(__file__).resolve().parent               # lr-assembly/rehearsal/
WORK = HERE / "work"
BENCHAPP = ROOT / "benchapp"
BASE = ROOT / "bench-prep" / "lab-assembly" / "rehearsal" / "work"
INPUT = HERE / "lr-rehearsal-input.csv"
ANCHOR_YML = "      - BenchImages/W-24.jpg"

def sha256(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()

def main() -> int:
    # --- doc bang input dong bang ---
    with INPUT.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    ids = [f"L-R{i:02d}" for i in range(1, 11)]
    assert [r["lr_id"] for r in rows] == ids, "input khong du/khong dung thu tu L-R01..L-R10"

    # --- nen dien tap lab phai o trang thai da dien tap xong ---
    base_cat = (BASE / "BenchCatalog.swift").read_text(encoding="utf-8")
    assert 'appBuild = "benchapp-2"' in base_cat and base_cat.count('origin: "lab"') == 24
    assert len(list((BASE / "BenchImages").glob("*"))) == 46, "nen lab khong co 46 anh"

    # --- ghi hash goc: benchapp THAT + nen lab (verifier doi chieu) ---
    orig = {
        "BenchCatalog.swift": sha256(BENCHAPP / "BenchCatalog.swift"),
        "project.yml": sha256(BENCHAPP / "project.yml"),
        "benchimages_count": str(len(list((BENCHAPP / "BenchImages").glob("*")))),
        "base_catalog_sha256": sha256(BASE / "BenchCatalog.swift"),
        "base_project_sha256": sha256(BASE / "project.yml"),
    }

    # --- sao nen -> work/ ---
    if WORK.exists():
        shutil.rmtree(WORK)
    (WORK / "BenchImages").mkdir(parents=True)
    shutil.copy2(BASE / "BenchCatalog.swift", WORK / "BenchCatalog.swift")
    shutil.copy2(BASE / "project.yml", WORK / "project.yml")
    for p in sorted((BASE / "BenchImages").glob("*")):
        shutil.copy2(p, WORK / "BenchImages" / p.name)

    # --- buoc 1: chep 10 anh dung thay -> L-Rnn.jpg, sha truoc/sau ---
    for r in rows:
        src = BENCHAPP / "BenchImages" / r["standin_file"]
        assert sha256(src) == r["sha256"], f'{r["lr_id"]}: sha anh dung thay lech bang input'
        dst = WORK / "BenchImages" / f'{r["lr_id"]}.jpg'
        shutil.copy2(src, dst)
        assert sha256(dst) == r["sha256"], f'{r["lr_id"]}: sha sau chep lech'

    # --- buoc 2+4+5: dien tung muc L-R trong catalog ban sao ---
    cat = (WORK / "BenchCatalog.swift").read_text(encoding="utf-8")
    for r in rows:
        lid = r["lr_id"]
        pages = r["pages"] if r["pages"] else "nil"
        block = (
            "        BenchImageDefinition(\n"
            f'            id: "{lid}", form: "{r["form"]}", difficulty: "{r["difficulty"]}", origin: "real",\n'
            f'            gtID: "{r["gt_id"]}",\n'
            f'            sourceFile: "REHEARSAL-STANDIN-{r["standin_file"]}",\n'
            f'            resourceName: "{lid}", pages: {pages},\n'
            f'            statusNote: "Sẵn sàng (DIỄN TẬP — ảnh đứng thay {r["standin_file"]}, phân loại + GT kế thừa ca hạt giống nguồn; KHÔNG phải hoá đơn thật của anh)."),'
        )
        pat = re.compile(
            r'        BenchImageDefinition\(\n'
            rf'            id: "{lid}", form: "\?", difficulty: "\?", origin: "real",\n'
            r'            gtID: "", sourceFile: nil, resourceName: nil,\n'
            r'            pages: nil, statusNote: "THIẾU — [^"]*"\),')
        cat, n = pat.subn(block.replace("\\", "\\\\"), cat, count=1)
        assert n == 1, f"{lid}: khong tim thay o trong nguyen trang de dien (n={n})"
    assert 'form: "?"' not in cat, "con o L-R chua dien"

    # --- nang dau ban (chi ban sao) ---
    assert cat.count('appBuild = "benchapp-2"') == 1
    cat = cat.replace('appBuild = "benchapp-2"', 'appBuild = "benchapp-3"', 1)
    (WORK / "BenchCatalog.swift").write_text(cat, encoding="utf-8")

    # --- buoc 3: them 10 dong sources sau dong W-24 ---
    yml = (WORK / "project.yml").read_text(encoding="utf-8")
    assert ANCHOR_YML in yml and "BenchImages/L-R" not in yml
    add = "\n".join(f"      - BenchImages/{lid}.jpg" for lid in ids)
    yml = yml.replace(ANCHOR_YML, ANCHOR_YML + "\n" + add, 1)
    (WORK / "project.yml").write_text(yml, encoding="utf-8")

    # --- manifest dien tap ---
    with (HERE / "lr-rehearsal-manifest.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["lr_id", "standin_file", "form", "difficulty", "gt_id", "pages", "sha256", "bytes"])
        for r in rows:
            w.writerow([r["lr_id"], r["standin_file"], r["form"], r["difficulty"], r["gt_id"], r["pages"], r["sha256"], r["bytes"]])
        for k in ["BenchCatalog.swift", "project.yml", "benchimages_count", "base_catalog_sha256", "base_project_sha256"]:
            w.writerow(["#ORIG", k, orig[k]])
    print(f"LR-REHEARSAL OK: work/ = catalog 69 muc (L-R da dien 10/10) + project + {len(list((WORK/'BenchImages').glob('*')))} anh (46 nen + 10 L-R); appBuild ban sao = benchapp-3")
    return 0

if __name__ == "__main__":
    sys.exit(main())
