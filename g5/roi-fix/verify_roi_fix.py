#!/usr/bin/env python3
# Kiểm chứng gói G5-ROIFIX (ca trực 20:40 CST 2026-11-15) — NGOẠI TUYẾN.
# Không có swiftc tại bàn: kiểm ở 3 tầng (1) tĩnh trên file Swift đã vá,
# (2) gương logic range/band chạy trên bằng chứng thật của 4 ca #37,
# (3) chứa trọn hình học trên 41 luồng đóng băng run31.
# Mọi số đều đọc từ file trên đĩa trong lúc chạy, không hard-code kết quả.
import difflib
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path("/home/hatch/workspace/receipt-app")
ORIG = ROOT / "g5/app/ReadPipeline.swift"
PATCHED = ROOT / "g5/roi-fix/ReadPipeline.swift"
EVID = ROOT / "g5/checks/evidence-37"
RUN31 = ROOT / "core-v4-design/run31/streams"

results = []
def check(name, ok, detail=""):
    results.append((name, ok, detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name}  {detail}")

# ---------- Tầng 1: tĩnh ----------
orig_text = ORIG.read_text()
patched_text = PATCHED.read_text()
check("file gốc g5/app không bị đụng (md5 c511322f…)",
      hashlib.md5(orig_text.encode()).hexdigest()
      == "c511322f487b5b85b5fcc391af3743dc")
check("bản vá khác bản gốc", orig_text != patched_text)
check("ngoặc nhọn cân bằng ở cả hai bản",
      orig_text.count("{") == orig_text.count("}")
      and patched_text.count("{") == patched_text.count("}"),
      f"gốc {orig_text.count('{')}/{orig_text.count('}')} "
      f"vá {patched_text.count('{')}/{patched_text.count('}')}")

diff = list(difflib.unified_diff(orig_text.splitlines(),
                                 patched_text.splitlines(), lineterm=""))
changed = [l for l in diff if (l.startswith("+") or l.startswith("-"))
           and not l.startswith("+++") and not l.startswith("---")]
# Mọi dòng thay đổi phải nằm trong 2 vùng cho phép: điểm gọi appendHint
# (chứa 'arbiterFallbackBand' / 'band: arbiterBand') hoặc hàm mới + comment.
allowed = ("arbiterFallbackBand", "arbiterBand(for: range",
           "G5-ROIFIX", "BAND DỰ PHÒNG", "Khối món", "Khối tổng",
           "Hình học dự phòng", "range nil", "roiAssertFail",
           "WR-starbucks-1", "không bao giờ mở", "không nặn số",
           "không phạm AMD-V4-01", "arbiterIsBetter",
           "private static func arbiterFallbackBand",
           "block: ReconcileRegionHint.Block) -> CGRect {",
           "switch block {", "case .items:", "case .totals:",
           "return CGRect(x: 0, y: 0, width: 1, height: 1)",
           "return CGRect(x: 0, y: 0, width: 1, height: 0.9)",
           "}", "///", "ROI là tầng", "nhận arbiterIsBetter",
           " WR-dollartree-1,", "(4 ca", "L-R09,",
           "2026-11-15): BAND")
bad = [l for l in changed
       if not any(a in l for a in allowed) and l[1:].strip() not in ("",)]
check("diff chỉ nằm trong 2 vùng cho phép (điểm gọi + hàm mới)",
      not bad, f"{len(changed)} dòng thay đổi, ngoài vùng: {bad[:3]}")
check("hàm arbiterFallbackBand: đúng 1 định nghĩa + 1 điểm gọi",
      patched_text.count("func arbiterFallbackBand") == 1
      and patched_text.count("?? arbiterFallbackBand(block: block)") == 1)

# ---------- Tầng 2: gương logic trên 4 ca bằng chứng #37 ----------
def totals_label_indices(lines):
    return [i for i, l in enumerate(lines)
            if any(k in l["text"].upper() for k in ("SUBTOTAL", "TOTAL", "TAX"))]

def band_from_range(rng, boxes):
    # Gương arbiterBand: hợp hộp các dòng trong range, nở x2 chiều cao quanh tâm.
    if rng is None:
        return None
    rects = [boxes[i] for i in range(rng[0], rng[1] + 1)
             if 0 <= i < len(boxes) and boxes[i] is not None]
    if not rects:
        return None
    y0 = min(r["y"] for r in rects)
    y1 = max(r["y"] + r["h"] for r in rects)
    h = (y1 - y0) * 2
    mid = (y0 + y1) / 2
    return (0.0, mid - h / 2, 1.0, h)

def fallback_band(block):
    # Gương arbiterFallbackBand của bản vá.
    return (0.0, 0.0, 1.0, 1.0) if block == "items" else (0.0, 0.0, 1.0, 0.9)

CASES = {  # ca -> khối hint quyết định (từ sổ mổ ca 18:40)
    "L-R09": "totals",
    "WR-dollartree-1": "items",
    "WR-starbucks-1": "items",
    "WR-traderjoes-1": "items",
}
for name, block in CASES.items():
    d = json.loads((EVID / f"{name}.stream.json").read_text())
    lines = d["assembled"]
    boxes = [l["box"] for l in lines]
    items_n = int(re.search(r"items=(\d+)", d["parse"]).group(1))
    if block == "items":
        rng = (0, 0) if items_n > 0 else None  # 0 món => không chỉ số dòng nào
    else:
        idx = totals_label_indices(lines)
        rng = (min(idx), max(idx)) if idx else None
    band_now = band_from_range(rng, boxes)
    band_new = band_now if band_now is not None else fallback_band(block)
    check(f"{name}: logic HIỆN HÀNH cho band nil (tái hiện roiRounds=0)",
          band_now is None, f"items={items_n} range={rng}")
    check(f"{name}: logic ĐÃ VÁ cho band dự phòng hợp lệ",
          band_new is not None and band_new[2] == 1.0 and band_new[3] > 0,
          f"band={band_new}")

# ---------- Tầng 3: chứa trọn trên 41 luồng run31 ----------
def totals_block(lines):
    tot = []
    for l in lines:
        u = l["text"].upper()
        if "DESCRIPTION" in u:
            continue
        if ("SUBTOTAL" in u or u.strip().startswith("TOTAL")
                or " TAX" in u or u.strip().startswith("TAX")):
            tot.append(l)
    if not tot:
        return None
    return (min(l["box"]["y"] for l in tot),
            max(l["box"]["y"] + l["box"]["h"] for l in tot))

streams = sorted(RUN31.glob("*.stream.json"))
contained = with_totals = fallback_not_used = range_cases = 0
for p in streams:
    d = json.loads(p.read_text())
    lines = d.get("assembled") or []
    if not lines:
        continue
    tb = totals_block(lines)
    if tb is None:
        continue
    with_totals += 1
    fb = fallback_band("totals")
    if fb[1] <= tb[0] and tb[1] <= fb[1] + fb[3]:
        contained += 1
    # Không hồi quy theo cấu trúc: có dòng nhãn tổng => range tồn tại
    # => bản vá KHÔNG dùng band dự phòng (band giữ nguyên như cũ).
    idx = totals_label_indices(lines)
    if idx:
        range_cases += 1
        b = band_from_range((min(idx), max(idx)), [l["box"] for l in lines])
        if b is not None:
            fallback_not_used += 1
check("dải tổng dự phòng [0, 0.9] chứa trọn khối tổng đã đo",
      with_totals > 0 and contained == with_totals,
      f"{contained}/{with_totals} luồng run31 có khối tổng")
check("ca có range thật: band dự phòng KHÔNG được dùng (không hồi quy)",
      range_cases > 0 and fallback_not_used == range_cases,
      f"{fallback_not_used}/{range_cases} ca có range")

# L-R09 đối chiếu chéo: run31 đọc được khối tổng của chính tờ này.
d = json.loads((RUN31 / "L-R09.stream.json").read_text())
tb = totals_block(d["assembled"])
fb = fallback_band("totals")
check("L-R09 run31: khối tổng thật nằm trong dải dự phòng",
      tb is not None and fb[1] <= tb[0] and tb[1] <= fb[1] + fb[3],
      f"khối tổng run31 y={tb}")

failed = [r for r in results if not r[1]]
print(f"\nTỔNG: {len(results) - len(failed)}/{len(results)} PASS")
sys.exit(1 if failed else 0)
