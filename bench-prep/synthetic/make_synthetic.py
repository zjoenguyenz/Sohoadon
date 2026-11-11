#!/usr/bin/env python3
"""Create the frozen synthetic degradation set for the single bench session.

Spec source: bench-prep/BENCH-MANIFEST.md section 4 + core-redo/ACCEPTANCE.md
section 3.2: 3 seed roots x 6 transforms = 18 images, origin "synthetic",
ground truth inherited unchanged from the root. Moderate ("nang vua") level,
every parameter frozen in this file and echoed into synthetic-manifest.csv.

Deterministic: fixed seed base; noise is generated per file from a seed
derived from (base seed, root, transform) by a stable formula, never from
hash() (which is salted per process). Re-running this script must reproduce
byte-identical JPEGs; verify_synthetic.py checks exactly that.

Transforms (one level each):
  BLUR    Gaussian blur, radius 1.5 px
  DOWNSCALE downsample x0.5 (BICUBIC) then upsample back to original size
            (BICUBIC). Root 002 is already a genuine low-resolution case
            (554 px wide); x0.5 is used for all roots for one frozen level,
            and the x0.25 idea in the manifest table is NOT applied to 002
            for that reason (recorded in SYNTHETIC-LEDGER.md).
  LIGHT   gamma 0.62 (over-bright) + linear brightness gradient, +0% at
            left edge to +18% at right edge (one-sided light streak)
  TILT    perspective keystone (top corners pulled in by 3% of width,
            bottom corners pushed out by 1.5%) then rotate 3.0 degrees,
            white fill
  WRINKLE sinusoidal geometric warp (x-shift amplitude 6 px, period
            height/5; y-shift amplitude 3 px, period width/2), nearest-
            neighbour remap, plus sinusoidal brightness bands (+/-6%,
            period height/5, phase-shifted)
  NOISE   additive Gaussian noise sigma 12.0 (seeded), saved JPEG q=20

All other outputs are saved JPEG quality 90 so compression itself does not
confound the named transform. Output size always equals the source size.
"""
import csv
import hashlib
import io
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SAMPLES = os.path.join(HERE, "..", "..", "samples")
OUTDIR = os.path.join(HERE, "images")
SEED_BASE = 20261110

ROOTS = [
    # (root_id, source_file, gt_id)
    ("001", "sample-001-sams-club-app-screenshot.jpg", "GT-SAMS-F"),
    ("002", "sample-002-sams-downloaded-receipt.jpg", "GT-SAMS-F"),
    ("003", "sample-003-homedepot-paper-crop.jpg", "GT-HD-003"),
]

TRANSFORM_IDS = ["BLUR", "DOWNSCALE", "LIGHT", "TILT", "WRINKLE", "NOISE"]


def t_blur(im):
    return im.filter(ImageFilter.GaussianBlur(radius=1.5)), "gaussian_blur radius=1.5px"


def t_downscale(im):
    w, h = im.size
    small = im.resize((max(1, w // 2), max(1, h // 2)), Image.BICUBIC)
    return small.resize((w, h), Image.BICUBIC), "downsample x0.5 bicubic, upsample back bicubic"


def t_light(im):
    w, h = im.size
    arr = np.asarray(im).astype(np.float64) / 255.0
    arr = np.power(arr, 0.62)  # gamma < 1 brightens
    grad = np.linspace(1.00, 1.18, w, dtype=np.float64)[None, :, None]
    arr = np.clip(arr * grad, 0.0, 1.0)
    return Image.fromarray((arr * 255).astype(np.uint8)), \
        "gamma=0.62 over-bright; brightness gradient 1.00->1.18 left->right"


def _perspective_coeffs(pa, pb):
    """Coefficients mapping output (pb) coordinates to input (pa)."""
    matrix = []
    for p1, p2 in zip(pa, pb):
        matrix.append([p2[0], p2[1], 1, 0, 0, 0, -p1[0] * p2[0], -p1[0] * p2[1]])
        matrix.append([0, 0, 0, p2[0], p2[1], 1, -p1[1] * p2[0], -p1[1] * p2[1]])
    a = np.matrix(matrix, dtype=float)
    b = np.array(pa).reshape(8)
    res = np.linalg.solve(a, b)
    return np.array(res).reshape(8)


def t_tilt(im):
    w, h = im.size
    # Keystone: where each output corner samples from in the source.
    src = [(0.03 * w, 0), (0.97 * w, 0), (1.015 * w, h), (-0.015 * w, h)]
    dst = [(0, 0), (w, 0), (w, h), (0, h)]
    coeffs = _perspective_coeffs(src, dst)
    out = im.transform((w, h), Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    out = out.rotate(3.0, resample=Image.BICUBIC, expand=False, fillcolor=(255, 255, 255))
    return out, "keystone top-in 3%W bottom-out 1.5%W; rotate 3.0deg bicubic white-fill"


def t_wrinkle(im):
    w, h = im.size
    arr = np.asarray(im).astype(np.float64)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    sx = xx - 6.0 * np.sin(2.0 * math.pi * yy / (h / 5.0))
    sy = yy - 3.0 * np.sin(2.0 * math.pi * xx / (w / 2.0))
    sxi = np.clip(np.round(sx).astype(int), 0, w - 1)
    syi = np.clip(np.round(sy).astype(int), 0, h - 1)
    warped = arr[syi, sxi]
    bands = (1.0 + 0.06 * np.sin(2.0 * math.pi * yy / (h / 5.0) + 1.1))[:, :, None]
    warped = np.clip(warped * bands, 0, 255)
    return Image.fromarray(warped.astype(np.uint8)), \
        "warp x-amp 6px period H/5, y-amp 3px period W/2, nearest; brightness bands +/-6% period H/5"


def t_noise(im, seed):
    rng = np.random.default_rng(seed)
    arr = np.asarray(im).astype(np.float64)
    arr = np.clip(arr + rng.normal(0.0, 12.0, arr.shape), 0, 255)
    return Image.fromarray(arr.astype(np.uint8)), "gaussian noise sigma=12.0 seeded; jpeg q=20"


TRANSFORMS = {
    "BLUR": t_blur,
    "DOWNSCALE": t_downscale,
    "LIGHT": t_light,
    "TILT": t_tilt,
    "WRINKLE": t_wrinkle,
    # NOISE handled specially (needs a seed)
}


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def main(outdir=OUTDIR):
    os.makedirs(outdir, exist_ok=True)
    rows = []
    for r_idx, (root_id, src_name, gt_id) in enumerate(ROOTS):
        src_path = os.path.join(SAMPLES, src_name)
        with open(src_path, "rb") as f:
            src_sha = sha256_bytes(f.read())
        base = Image.open(src_path).convert("RGB")
        w, h = base.size
        for t_idx, t_id in enumerate(TRANSFORM_IDS):
            out_id = f"SYN-{root_id}-{t_id}"
            if t_id == "NOISE":
                seed = SEED_BASE + r_idx * 100 + t_idx
                out, params = t_noise(base, seed)
                params += f"; seed={seed}"
                quality = 20
            else:
                out, params = TRANSFORMS[t_id](base)
                quality = 90
            assert out.size == (w, h), (out_id, out.size, (w, h))
            buf = io.BytesIO()
            out.save(buf, format="JPEG", quality=quality)
            data = buf.getvalue()
            fname = f"{out_id}.jpg"
            with open(os.path.join(outdir, fname), "wb") as f:
                f.write(data)
            rows.append({
                "id": out_id,
                "root_id": root_id,
                "gt_id": gt_id,
                "origin": "synthetic",
                "transform": t_id,
                "source_file": src_name,
                "source_sha256": src_sha,
                "output_file": f"images/{fname}",
                "width_px": w,
                "height_px": h,
                "bytes": len(data),
                "sha256": sha256_bytes(data),
                "jpeg_quality": quality,
                "params": params,
            })
            print(f"{out_id}: {w}x{h} {len(data)} bytes")
    manifest = os.path.join(HERE, "synthetic-manifest.csv")
    with open(manifest, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {len(rows)} rows -> {manifest}")
    return rows


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else OUTDIR)
