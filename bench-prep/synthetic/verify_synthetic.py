#!/usr/bin/env python3
"""Verify the frozen synthetic set against synthetic-manifest.csv.

Checks, all against files on disk (no Vision is run here -- these images are
only scorable on-device in the single bench session):
  1. exactly 18 manifest rows, 18 image files, no extras, no missing
  2. every output's bytes + sha256 match the manifest
  3. every output's pixel dimensions equal its root source's dimensions
  4. every output actually differs from its root source (transform applied)
  5. reproducibility: regenerating into a temp dir reproduces every sha256
     byte-for-byte
Prints one line per check group and a final PASS/FAIL; exit code mirrors it.
"""
import csv
import hashlib
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_synthetic as ms  # noqa: E402
from PIL import Image  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
failures = []


def check(label, ok, detail=""):
    print(f"{'PASS' if ok else 'FAIL'}  {label}  {detail}")
    if not ok:
        failures.append(label)


def sha256_file(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def main():
    with open(os.path.join(HERE, "synthetic-manifest.csv"), encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    check("manifest rows == 18", len(rows) == 18, f"got {len(rows)}")
    files = sorted(x for x in os.listdir(ms.OUTDIR) if x.endswith(".jpg"))
    check("image files == 18", len(files) == 18, f"got {len(files)}")
    listed = sorted(os.path.basename(r["output_file"]) for r in rows)
    check("files on disk == files in manifest", files == listed)

    src_dims = {}
    for root_id, src_name, _gt in ms.ROOTS:
        with Image.open(os.path.join(ms.SAMPLES, src_name)) as im:
            src_dims[root_id] = im.size

    bad_hash, bad_dim, same_as_src = [], [], []
    for r in rows:
        path = os.path.join(HERE, r["output_file"])
        if sha256_file(path) != r["sha256"] or os.path.getsize(path) != int(r["bytes"]):
            bad_hash.append(r["id"])
        with Image.open(path) as im:
            if im.size != src_dims[r["root_id"]] or im.size != (int(r["width_px"]), int(r["height_px"])):
                bad_dim.append(r["id"])
        if sha256_file(path) == r["source_sha256"]:
            same_as_src.append(r["id"])
    check("sha256+bytes match manifest for all 18", not bad_hash, ",".join(bad_hash))
    check("dimensions equal root source for all 18", not bad_dim, ",".join(bad_dim))
    check("every output differs from its source", not same_as_src, ",".join(same_as_src))

    combos = {(r["root_id"], r["transform"]) for r in rows}
    expect = {(root, t) for root, _s, _g in ms.ROOTS for t in ms.TRANSFORM_IDS}
    check("all 3 roots x 6 transforms present", combos == expect,
          f"missing={sorted(expect - combos)}")

    with tempfile.TemporaryDirectory() as td:
        regen_dir = os.path.join(td, "images")
        ms.main(regen_dir)
        regen_rows = {}
        with open(os.path.join(HERE, "synthetic-manifest.csv"), encoding="utf-8") as f:
            pass  # manifest was rewritten by regen with identical content target
        # Compare regenerated files against the frozen ones by name+hash.
        mism = []
        for r in rows:
            regen_path = os.path.join(regen_dir, os.path.basename(r["output_file"]))
            if not os.path.exists(regen_path) or sha256_file(regen_path) != r["sha256"]:
                mism.append(r["id"])
        check("regeneration reproduces all 18 byte-for-byte", not mism, ",".join(mism))

    print("RESULT:", "PASS" if not failures else f"FAIL ({len(failures)} groups)")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
