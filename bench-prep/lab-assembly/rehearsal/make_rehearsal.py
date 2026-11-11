#!/usr/bin/env python3
"""DIEN TAP RAP LAB (rehearsal) — ap cong thuc co hoc trong
LAB-ASSEMBLY-DECISION.md vao MOT BAN SAO CACH LY cua benchapp/,
KHONG dung benchapp/ that.

Dau vao dong bang:
  - benchapp/BenchCatalog.swift + benchapp/project.yml + benchapp/BenchImages/ (22 file)
  - bench-prep/lab-staging/lab-staging-manifest.csv (staging 24 anh W)
  - bench-prep/lab-wildreceipt/wildreceipt-subset.csv (duong dan corpus nguyen van)
  - LAB-ASSEMBLY-DECISION.md Quyet 2: form C ca 24; LONG/TALL->L5, DENSE/LOWRES->L4

Dau ra: rehearsal/work/ (BenchCatalog.swift, project.yml, BenchImages/ 46 file)
+ rehearsal-manifest.csv. Xac dinh: chay lai tao byte-trung.
"""
import csv, hashlib, shutil, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]          # receipt-app/
HERE = Path(__file__).resolve().parent               # rehearsal/
WORK = HERE / "work"
BENCHAPP = ROOT / "benchapp"
STAGING = ROOT / "bench-prep" / "lab-staging"
SUBSET = ROOT / "bench-prep" / "lab-wildreceipt" / "wildreceipt-subset.csv"

DIFF = {"LONG": "L5", "TALL": "L5", "DENSE": "L4", "LOWRES": "L4"}
ANCHOR_CATALOG = "        // --- 10 ô trống cho hoá đơn THẬT anh sắp gửi (L-R01…L-R10) ---"
ANCHOR_YML = "      - BenchImages/SYN-003-NOISE.jpg"

def sha256(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()

def main() -> int:
    # --- doc bang ke dong bang ---
    with (STAGING / "lab-staging-manifest.csv").open(newline="", encoding="utf-8") as f:
        staging = {r["case_id"]: r for r in csv.DictReader(f)}
    with SUBSET.open(newline="", encoding="utf-8") as f:
        subset = {r["case_id"]: r for r in csv.DictReader(f)}
    ids = [f"W-{i:02d}" for i in range(1, 25)]
    assert sorted(staging) == ids and sorted(subset) == ids, "bang ke khong du 24 ca W"

    # --- ghi hash goc cua benchapp that (de verifier chung minh khong bi dung) ---
    orig = {
        "BenchCatalog.swift": sha256(BENCHAPP / "BenchCatalog.swift"),
        "project.yml": sha256(BENCHAPP / "project.yml"),
        "benchimages_count": str(len(list((BENCHAPP / "BenchImages").glob("*")))),
    }

    # --- lam sach + sao chep ban sao cach ly ---
    if WORK.exists():
        shutil.rmtree(WORK)
    (WORK / "BenchImages").mkdir(parents=True)
    shutil.copy2(BENCHAPP / "BenchCatalog.swift", WORK / "BenchCatalog.swift")
    shutil.copy2(BENCHAPP / "project.yml", WORK / "project.yml")
    for p in sorted((BENCHAPP / "BenchImages").glob("*")):
        shutil.copy2(p, WORK / "BenchImages" / p.name)

    # --- buoc (1): chep 24 anh staging -> BenchImages/W-nn.jpg, doi chieu sha truoc/sau ---
    rows = []
    for cid in ids:
        src = STAGING / "images" / f"{cid}.jpg"
        assert sha256(src) == staging[cid]["sha256"] == subset[cid]["sha256"], f"{cid}: sha staging != bang ke/subset"
        dst = WORK / "BenchImages" / f"{cid}.jpg"
        shutil.copy2(src, dst)
        assert sha256(dst) == staging[cid]["sha256"], f"{cid}: sha sau chep lech"
        rows.append({
            "case_id": cid, "stratum": staging[cid]["stratum"],
            "form": "C", "difficulty": DIFF[staging[cid]["stratum"]],
            "origin": "lab", "gt_id": "",
            "source_file": subset[cid]["file_name"],
            "sha256": staging[cid]["sha256"], "bytes": staging[cid]["bytes"],
        })

    # --- buoc (2): them 24 muc BenchCatalog theo Quyet 1+2 ---
    cat = (WORK / "BenchCatalog.swift").read_text(encoding="utf-8")
    assert ANCHOR_CATALOG in cat, "khong tim thay neo chen trong BenchCatalog ban sao"
    assert 'id: "W-' not in cat, "ban sao da co muc W (khong phai ban goc)"
    blocks = []
    blocks.append("        // --- 24 ca LAB WildReceipt (W-01…W-24, LAB-ASSEMBLY-DECISION) ---")
    blocks.append("        // origin = lab: cham tay ho so LAB theo nhan nguyen van, khong GT,")
    blocks.append("        // khong cong, khong trong so/lop (bo cham bo qua khoi vong GT).")
    for r in rows:
        blocks.append("        BenchImageDefinition(")
        blocks.append(f'            id: "{r["case_id"]}", form: "C", difficulty: "{r["difficulty"]}", origin: "lab",')
        blocks.append('            gtID: "",')
        blocks.append(f'            sourceFile: "{r["source_file"]}",')
        blocks.append(f'            resourceName: "{r["case_id"]}", pages: nil,')
        blocks.append(f'            statusNote: "Sẵn sàng — LAB tầng {r["stratum"]} — chấm tay hồ sơ LAB, không GT, không cổng."),')
    cat = cat.replace(ANCHOR_CATALOG, "\n".join(blocks) + "\n" + ANCHOR_CATALOG, 1)
    (WORK / "BenchCatalog.swift").write_text(cat, encoding="utf-8")

    # --- buoc (3): them 24 dong sources vao project.yml ---
    yml = (WORK / "project.yml").read_text(encoding="utf-8")
    assert ANCHOR_YML in yml and "BenchImages/W-" not in yml
    add = "\n".join(f"      - BenchImages/{cid}.jpg" for cid in ids)
    yml = yml.replace(ANCHOR_YML, ANCHOR_YML + "\n" + add, 1)
    (WORK / "project.yml").write_text(yml, encoding="utf-8")

    # --- manifest dien tap (kem hash goc de verifier doi chieu) ---
    with (HERE / "rehearsal-manifest.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["case_id", "stratum", "form", "difficulty", "origin", "gt_id", "source_file", "sha256", "bytes"])
        for r in rows:
            w.writerow([r["case_id"], r["stratum"], r["form"], r["difficulty"], r["origin"], r["gt_id"], r["source_file"], r["sha256"], r["bytes"]])
        w.writerow(["#ORIG", "BenchCatalog.swift", orig["BenchCatalog.swift"]])
        w.writerow(["#ORIG", "project.yml", orig["project.yml"]])
        w.writerow(["#ORIG", "benchimages_count", orig["benchimages_count"]])
    print(f"REHEARSAL OK: work/ = catalog+project + {len(list((WORK/'BenchImages').glob('*')))} anh (22 goc + 24 lab)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
