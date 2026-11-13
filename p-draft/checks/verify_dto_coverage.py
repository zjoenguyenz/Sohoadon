#!/usr/bin/env python3
"""Kiểm độ phủ trường của các DTO trong gói P-DRAFT.

Mục đích: chứng minh tại bàn rằng ánh xạ hai chiều trong
PendingDraft.swift không làm rơi THẦM bất kỳ thuộc tính lưu trữ
nào của các kiểu gốc (ParseResult, ParsedLineItem, ParsedTaxLine,
TotalCandidate, ReconcileReport, ReconcileFix, ReconcileRegionHint,
ScanDraft). Script trích danh sách thuộc tính `var/let` ở tầng cao
nhất của từng struct từ CHÍNH mã nguồn thật trong cây assembled,
trừ các thuộc tính tính toán/hàm đã khai báo tường minh, rồi so
với danh sách trường của DTO tương ứng (kể cả các đổi tên đã ghi
chú: *Raw, lineRange -> lineRangeLower/Upper).

Chạy: python3 verify_dto_coverage.py <thư mục cây assembled>
Mặc định: ../assembled so với file này.
"""
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent.parent / "assembled"


def struct_body(source: str, type_name: str) -> str:
    """Lấy thân của `struct <type_name> { ... }` bằng đếm ngoặc."""
    m = re.search(r"\bstruct\s+" + re.escape(type_name) + r"\b[^{]*\{", source)
    if not m:
        raise SystemExit(f"Không tìm thấy struct {type_name}")
    start = m.end() - 1  # vị trí '{'
    depth = 0
    for i in range(start, len(source)):
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0:
                return source[start + 1 : i]
    raise SystemExit(f"Ngoặc không cân trong {type_name}")


def top_level_props(body: str) -> list[str]:
    """Thuộc tính var/let khai ở độ sâu ngoặc 0 của thân struct
    (bỏ qua các thuộc tính nằm trong hàm/ext lồng nhau)."""
    props = []
    depth = 0
    for line in body.splitlines():
        stripped = line.strip()
        if depth == 0:
            m = re.match(r"(?:var|let)\s+(\w+)\s*[:=]", stripped)
            if m and not stripped.startswith("var body"):
                props.append(m.group(1))
        depth += line.count("{") - line.count("}")
    return props


def load(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


parser_src = load("Parser.swift")
reconcile_src = load("Reconcile.swift")
scan_src = load("ScanView.swift")
dto_src = load("PendingDraft.swift")

# (kiểu gốc, file gốc, DTO, {trường gốc: tên trường DTO}, trường gốc loại trừ có lý do)
CASES = [
    ("ParsedLineItem", parser_src, "ParsedLineItemDTO", {}, set()),
    ("ParsedTaxLine", parser_src, "ParsedTaxLineDTO", {}, set()),
    ("TotalCandidate", parser_src, "TotalCandidateDTO", {}, set()),
    ("ParseResult", parser_src, "ParseResultDTO", {},
     {"taxTotalCents"}),  # thuộc tính TÍNH TOÁN từ taxes — không lưu
    ("ReconcileFix", reconcile_src, "ReconcileFixDTO",
     {"field": "fieldRaw", "channel": "channelRaw"}, set()),
    ("ReconcileRegionHint", reconcile_src, "ReconcileRegionHintDTO",
     {"block": "blockRaw", "reason": "reasonRaw",
      "lineRange": "lineRangeLower+lineRangeUpper"}, set()),
    ("ReconcileReport", reconcile_src, "ReconcileReportDTO",
     {"status": "statusRaw"},
     set()),  # appliedFix(forItemAt:) là HÀM, không phải thuộc tính
    ("ScanDraft", scan_src, "PendingDraftSnapshot",
     {"result": "result", "sourceType": "sourceTypeRaw"},
     {"id"}),  # id = định danh phiên hiển thị, khôi phục nhận id mới
]

failures = 0
for original, src, dto_name, renames, excluded in CASES:
    orig_props = [p for p in top_level_props(struct_body(src, original)) if p not in excluded]
    dto_props = top_level_props(struct_body(dto_src, dto_name))
    if dto_name == "PendingDraftSnapshot":
        # Snapshot có thêm trường hạ tầng của chính nó.
        dto_props = [p for p in dto_props
                     if p not in ("schemaVersion", "createdAt")]
    expected = []
    for p in orig_props:
        mapped = renames.get(p, p)
        expected.extend(mapped.split("+"))
    missing = [p for p in expected if p not in dto_props]
    extra = [p for p in dto_props if p not in expected]
    status = "PASS" if not missing and not extra else "FAIL"
    if status == "FAIL":
        failures += 1
    print(f"[{status}] {original} -> {dto_name}: gốc {len(orig_props)} trường, "
          f"DTO {len(dto_props)} trường"
          + (f", THIẾU: {missing}" if missing else "")
          + (f", THỪA: {extra}" if extra else ""))

print("KẾT QUẢ:", "PASS TOÀN BỘ" if failures == 0 else f"FAIL {failures} cặp")
sys.exit(1 if failures else 0)
