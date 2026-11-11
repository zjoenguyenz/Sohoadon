#!/usr/bin/env python3
"""Stage the frozen 24 WildReceipt lab images for the final bench assembly.

Deterministic copier: reads ONLY the frozen subset table
``bench-prep/lab-wildreceipt/wildreceipt-subset.csv`` (case_id +
file_name + sha256 + bytes), copies each source image byte-for-byte
from ``corpus/lab/wildreceipt/extracted/wildreceipt/<file_name>``
to ``bench-prep/lab-staging/images/W-nn.jpg``, verifies sha256 +
byte-size against the subset table BEFORE accepting each copy, and
writes ``lab-staging-manifest.csv``.

This pack is STAGING only: nothing here is registered in
BenchCatalog / project.yml and nothing is copied into BenchApp.
Final assembly (Leader, at the same beat as the L-R real cases)
copies ``images/W-nn.jpg`` -> ``benchapp/BenchImages/W-nn.jpg``
unchanged.

Source files carry a .jpeg suffix; staged files use .jpg because
BenchImages / BenchCatalog resourceExtension is "jpg" and the
payload is JPEG either way (magic bytes are checked by the
independent verifier, not assumed here).
"""
import csv
import hashlib
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]  # receipt-app/
SUBSET = REPO / "bench-prep" / "lab-wildreceipt" / "wildreceipt-subset.csv"
SRC_ROOT = REPO / "corpus" / "lab" / "wildreceipt" / "extracted" / "wildreceipt"
OUT_DIR = HERE / "images"
MANIFEST = HERE / "lab-staging-manifest.csv"


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    rows = list(csv.DictReader(SUBSET.open(newline="", encoding="utf-8")))
    if len(rows) != 24:
        print(f"FATAL: subset has {len(rows)} rows, expected 24")
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_rows = []
    total = 0
    for row in rows:
        case_id = row["case_id"]
        src = SRC_ROOT / row["file_name"]
        if not src.is_file():
            print(f"FATAL: source missing for {case_id}: {src}")
            return 1
        got_sha = sha256_of(src)
        got_bytes = src.stat().st_size
        if got_sha != row["sha256"] or got_bytes != int(row["bytes"]):
            print(f"FATAL: source drift for {case_id}: sha {got_sha} vs "
                  f"{row['sha256']}, bytes {got_bytes} vs {row['bytes']}")
            return 1
        dst = OUT_DIR / f"{case_id}.jpg"
        shutil.copyfile(src, dst)
        if sha256_of(dst) != got_sha or dst.stat().st_size != got_bytes:
            print(f"FATAL: staged copy mismatch for {case_id}")
            return 1
        total += got_bytes
        out_rows.append({
            "case_id": case_id,
            "staged_file": f"images/{case_id}.jpg",
            "source_file": row["file_name"],
            "sha256": got_sha,
            "bytes": got_bytes,
            "width": row["width"],
            "height": row["height"],
            "stratum": row["stratum"],
        })
        print(f"{case_id}: {row['file_name']} -> images/{case_id}.jpg "
              f"({got_bytes} bytes, sha256 {got_sha[:12]}...) OK")
    with MANIFEST.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(out_rows[0].keys()))
        w.writeheader()
        w.writerows(out_rows)
    print(f"STAGED 24/24 images, total {total} bytes")
    print(f"Manifest: {MANIFEST.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
