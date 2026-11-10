#!/usr/bin/env python3
"""
Port Python TRUNG THỰC của tầng ráp hàng WP4 (wp4-prep/ScanView.swift):
dedupeOverlap + mergeRows (CODE-AUDIT F2a/F2c). Mục đích duy nhất: kiểm
chứng THUẬT TOÁN trên mảnh tổng hợp dựng từ đáp án chuẩn Mẫu 002 trong
môi trường ca trực không có Vision/compiler. Đây KHÔNG phải bằng chứng
OCR thật — Vision trên máy mới là phép đo cổng (WP4-SPEC.md).
Box: (minX, minY, maxX, maxY) chuẩn hoá, gốc dưới-trái, không gian ảnh đầy đủ.
"""
from dataclasses import dataclass


@dataclass
class Frag:
    text: str
    confidence: float
    minx: float
    miny: float
    maxx: float
    maxy: float

    @property
    def w(self): return self.maxx - self.minx

    @property
    def h(self): return self.maxy - self.miny


def dedupe_overlap(frags):
    """Swift dedupeOverlap: xét theo confidence giảm dần; trùng = cùng chữ
    + diện tích giao >= 50% diện tích hộp nhỏ hơn -> bỏ bản yếu hơn."""
    kept = []
    for f in sorted(frags, key=lambda x: -x.confidence):
        dup = False
        for k in kept:
            if k.text != f.text:
                continue
            iw = min(k.maxx, f.maxx) - max(k.minx, f.minx)
            ih = min(k.maxy, f.maxy) - max(k.miny, f.miny)
            if iw <= 0 or ih <= 0:
                continue
            smaller = min(k.w * k.h, f.w * f.h)
            if smaller > 0 and (iw * ih) / smaller >= 0.5:
                dup = True
                break
        if not dup:
            kept.append(f)
    return kept


def merge_rows(frags):
    """Swift mergeRows (CODE-AUDIT F2a): sort maxY giảm dần; gom vào hàng
    cuối nếu chồng Y >= 50% chiều cao mảnh ngắn hơn (neo = mảnh đầu hàng);
    trong hàng sort minX tăng dần, nối ' ', confidence = min."""
    frags = sorted(frags, key=lambda x: -x.maxy)
    rows = []
    for f in frags:
        if rows:
            anchor = rows[-1][0]
            overlap = min(f.maxy, anchor.maxy) - max(f.miny, anchor.miny)
            shorter = min(f.h, anchor.h)
            if shorter > 0 and overlap / shorter >= 0.5:
                rows[-1].append(f)
                continue
        rows.append([f])
    lines = []
    for row in rows:
        s = sorted(row, key=lambda x: x.minx)
        lines.append((" ".join(x.text for x in s), min(x.confidence for x in s)))
    return lines
