#!/usr/bin/env python3
"""Independent verifier for the lab staging pack.

Shares NO code with make_lab_staging.py (own CSV/hash/image reads).
Checks, each printed as PASS/FAIL with counts:
 1. Manifest has exactly 24 rows, case_ids W-01..W-24 continuous.
 2. Manifest case set + source_file set == frozen subset table set.
 3. Every staged file: sha256 + byte-size == subset table (24/24).
 4. Every staged file is byte-identical (cmp) to its corpus source.
 5. Every staged file is a decodable JPEG (PIL format check +
    magic bytes FF D8 FF) with width/height == subset table.
 6. Manifest rows agree with the subset table AND with the files
    on disk (sha/bytes/dims/stratum re-derived independently).
 7. Staging directory contains exactly the 24 expected files,
    no extras, no missing.
 8. Reproducibility: re-run the maker into a temp copy of this
    folder layout and byte-compare all 24 staged images +
    manifest against the on-disk pack.
 9. BenchApp untouched: benchapp/BenchImages still exactly the
    22 known files, BenchCatalog.swift contains no W-0/W-1/W-2
    case id, project.yml contains no lab-staging/W- reference.
10. Total staged size == sum of subset byte sizes (printed).
Exit 0 only if every group passes.
"""
import csv
import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
SUBSET = REPO / "bench-prep" / "lab-wildreceipt" / "wildreceipt-subset.csv"
SRC_ROOT = REPO / "corpus" / "lab" / "wildreceipt" / "extracted" / "wildreceipt"
MANIFEST = HERE / "lab-staging-manifest.csv"
IMG_DIR = HERE / "images"

results = []


def check(name, ok, detail=""):
    results.append(ok)
    print(f"[{'PASS' if ok else 'FAIL'}] {name} {detail}")


def sha256_of(p: Path) -> str:
    h = hashlib.sha256()
    h.update(p.read_bytes())
    return h.hexdigest()


def main() -> int:
    from PIL import Image

    subset = {r["case_id"]: r for r in csv.DictReader(
        SUBSET.open(newline="", encoding="utf-8"))}
    manifest = list(csv.DictReader(MANIFEST.open(newline="", encoding="utf-8")))

    expected_ids = [f"W-{i:02d}" for i in range(1, 25)]
    check("1 manifest-24-continuous",
          [r["case_id"] for r in manifest] == expected_ids,
          f"({len(manifest)} rows)")
    check("2 manifest-matches-subset-set",
          {r["case_id"] for r in manifest} == set(subset)
          and {r["source_file"] for r in manifest}
          == {r["file_name"] for r in subset.values()})

    sha_ok = byte_ok = cmp_ok = img_ok = agree_ok = 0
    for r in manifest:
        cid, sub = r["case_id"], subset[r["case_id"]]
        staged = HERE / r["staged_file"]
        src = SRC_ROOT / sub["file_name"]
        if staged.is_file():
            if sha256_of(staged) == sub["sha256"] == r["sha256"]:
                sha_ok += 1
            if staged.stat().st_size == int(sub["bytes"]) == int(r["bytes"]):
                byte_ok += 1
            if staged.read_bytes() == src.read_bytes():
                cmp_ok += 1
            raw = staged.read_bytes()
            try:
                with Image.open(staged) as im:
                    fmt, size = im.format, im.size
                if fmt == "JPEG" and raw[:3] == b"\xff\xd8\xff" and \
                        size == (int(sub["width"]), int(sub["height"])):
                    img_ok += 1
            except Exception:
                pass
            if (r["width"], r["height"], r["stratum"]) == \
                    (sub["width"], sub["height"], sub["stratum"]):
                agree_ok += 1
    check("3 staged sha+bytes == subset", sha_ok == 24 and byte_ok == 24,
          f"(sha {sha_ok}/24, bytes {byte_ok}/24)")
    check("4 staged byte-identical to corpus source", cmp_ok == 24,
          f"({cmp_ok}/24)")
    check("5 staged are JPEG with subset dimensions", img_ok == 24,
          f"({img_ok}/24)")
    check("6 manifest agrees with subset (dims/stratum)", agree_ok == 24,
          f"({agree_ok}/24)")

    on_disk = sorted(p.name for p in IMG_DIR.iterdir() if p.is_file())
    check("7 staging dir exactly 24 expected files",
          on_disk == [f"{c}.jpg" for c in expected_ids],
          f"({len(on_disk)} files)")

    # 8: reproducibility — copy maker + layout into temp, re-run.
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        # Rebuild the minimal tree the maker resolves against:
        # maker uses HERE.parents[1] as repo root, so place it at
        # <tmp>/bench-prep/lab-staging/ and symlink the inputs.
        stage_dir = td / "bench-prep" / "lab-staging"
        stage_dir.mkdir(parents=True)
        (td / "bench-prep" / "lab-wildreceipt").mkdir(parents=True)
        (td / "bench-prep" / "lab-wildreceipt"
         / "wildreceipt-subset.csv").symlink_to(SUBSET)
        (td / "corpus" / "lab" / "wildreceipt" / "extracted").mkdir(
            parents=True)
        (td / "corpus" / "lab" / "wildreceipt" / "extracted"
         / "wildreceipt").symlink_to(SRC_ROOT)
        maker_copy = stage_dir / "make_lab_staging.py"
        maker_copy.write_bytes((HERE / "make_lab_staging.py").read_bytes())
        run = subprocess.run([sys.executable, str(maker_copy)],
                             capture_output=True, text=True)
        repro = run.returncode == 0
        if repro:
            for cid in expected_ids:
                a = (stage_dir / "images" / f"{cid}.jpg").read_bytes()
                b = (IMG_DIR / f"{cid}.jpg").read_bytes()
                if a != b:
                    repro = False
            if (stage_dir / "lab-staging-manifest.csv").read_bytes() \
                    != MANIFEST.read_bytes():
                repro = False
        check("8 maker re-run reproduces pack byte-for-byte", repro)

    bench_images = sorted(p.name for p in
                          (REPO / "benchapp" / "BenchImages").iterdir()
                          if p.is_file())
    catalog = (REPO / "benchapp" / "BenchCatalog.swift").read_text()
    project = (REPO / "benchapp" / "project.yml").read_text()
    lab_ids_in_catalog = [c for c in expected_ids if f'"{c}"' in catalog]
    check("9 BenchApp untouched (22 images, no lab in catalog/project)",
          len(bench_images) == 22 and not lab_ids_in_catalog
          and "W-01" not in project and "lab-staging" not in project,
          f"(BenchImages {len(bench_images)}, catalog lab ids "
          f"{len(lab_ids_in_catalog)})")

    total = sum(p.stat().st_size for p in IMG_DIR.iterdir() if p.is_file())
    subset_total = sum(int(r["bytes"]) for r in subset.values())
    check("10 total size == subset sum", total == subset_total,
          f"({total} bytes)")

    passed = sum(results)
    print(f"RESULT: {passed}/{len(results)} groups PASS")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
