# WP-EXPORT — bản gương Python của logic xuất bản gốc (WP-EXPORT-SPEC.md)
# Mục đích: khoá hành vi TRƯỚC khi viết Swift (đúng tiền lệ wp3/wp4/wp5:
# port chạy trên fixture cố định -> Swift dịch trung thực port này).
# Chỉ logic thuần: lọc theo loại/khoảng ngày, đặt tên file trong ZIP,
# sinh muc-luc.csv, ghi ZIP kiểu store. Không đụng Parser/Models.
#
# Ánh xạ trường Swift (wp3-prep/Models.swift, Receipt):
#   vendor, date, classification (personal/business/unknown), category,
#   subtotalCents, taxTotalCents (= Σ taxLines nếu có, else taxCents),
#   totalCents, cardLast4, allOriginalImageFileNames
#   (gộp imageFileName + originalImageFileNames, bỏ trùng/rỗng, giữ thứ tự).
# "File gốc nạp được" trong app = ImageStore đọc được byte của file đó;
# trong gương này, store là dict {tên file: bytes} — file vắng mặt trong
# dict = không nạp được (đúng ca tờ Home Depot thiếu ảnh gốc thật).

import csv
import io
import re
import unicodedata
import zipfile
from dataclasses import dataclass, field
from datetime import date


# ---------- mô hình dữ liệu gương (metadata thật / byte giả lập) ----------

@dataclass
class ReceiptRec:
    vendor: str
    day: date
    classification: str            # "business" | "personal" | "unknown"
    category: str = ""             # Mục
    subtotal_cents: int | None = None
    tax_cents: int | None = None   # = taxTotalCents đã gộp của Swift
    total_cents: int | None = None
    card_last4: str | None = None
    originals: list = field(default_factory=list)  # allOriginalImageFileNames


# ---------- helpers ----------

def money_text(cents):
    """10516 -> '105.16' ; None -> '' ; âm (hoàn hàng) -> '-5.00'."""
    if cents is None:
        return ""
    sign = "-" if cents < 0 else ""
    c = abs(cents)
    return f"{sign}{c // 100}.{c % 100:02d}"


def sanitize_vendor(name):
    """Bỏ dấu tiếng Việt + ký tự lạ cho tên file: 'Sam's Club' -> 'Sams-Club',
    'Quán Phở 79' -> 'Quan-Pho-79', 'The Home Depot' -> 'The-Home-Depot'.
    Rỗng sau khi làm sạch -> 'Khong-ten-tiem'."""
    nfd = unicodedata.normalize("NFD", name)
    stripped = "".join(ch for ch in nfd if unicodedata.category(ch) != "Mn")
    stripped = stripped.replace("Đ", "D").replace("đ", "d")
    # Dấu nháy bỏ hẳn (không thành gạch): "Sam's" -> "Sams", "Lowe's" -> "Lowes"
    stripped = stripped.replace("'", "").replace("’", "")
    cleaned = re.sub(r"[^A-Za-z0-9]+", "-", stripped).strip("-")
    return cleaned or "Khong-ten-tiem"


CLASS_LABEL = {"business": "Business", "personal": "Cá nhân",
               "unknown": "Chưa phân loại"}
FILTER_LABEL = {"business": "Business", "personal": "CaNhan", "all": "TatCa"}


def matches(rec, kind, d_from, d_to):
    """Lọc: loại (unknown chỉ vào 'Tất cả') + ngày hoá đơn, gồm cả 2 đầu."""
    if kind == "business" and rec.classification != "business":
        return False
    if kind == "personal" and rec.classification != "personal":
        return False
    return d_from <= rec.day <= d_to


def loadable_files(rec, store):
    """Trả (danh sách (tên-trong-ZIP-chưa-dedupe, bytes), số trang thiếu).
    Tên gốc: file chính theo tên chuẩn; trang phụ thêm '-trang2', '-trang3'…
    (WP-EXPORT-SPEC §2). Phần mở rộng giữ nguyên của file gốc."""
    out = []
    base = None
    for idx, fname in enumerate(rec.originals):
        if fname not in store:
            continue
        ext = fname.rsplit(".", 1)[-1].lower() if "." in fname else "jpg"
        if base is None:
            total_txt = money_text(rec.total_cents) or "chua-doc-duoc-tong"
            base = f"{rec.day.isoformat()}_{sanitize_vendor(rec.vendor)}_{total_txt}"
            out.append((f"{base}.{ext}", store[fname]))
        else:
            out.append((f"{base}-trang{idx + 1}.{ext}", store[fname]))
    missing_pages = len(rec.originals) - len(out) if out else 0
    return out, missing_pages


def dedupe_names(names):
    """Trùng tên trong ZIP -> hậu tố '-2', '-3'… chèn trước phần mở rộng,
    theo thứ tự xuất hiện (WP-EXPORT-SPEC §2)."""
    seen = {}
    result = []
    for n in names:
        if n not in seen:
            seen[n] = 1
            result.append(n)
            continue
        seen[n] += 1
        stem, dot, ext = n.rpartition(".")
        result.append(f"{stem}-{seen[n]}{dot}{ext}" if dot else f"{n}-{seen[n]}")
    return result


def build_export(receipts, store, kind, d_from, d_to):
    """Trả về dict: summary (số tờ khớp / tổng tiền cents / số tờ thiếu gốc),
    entries [(rec, [(zipname, bytes)], ghi_chú)], csv_bytes, zip_name.
    Thứ tự: ngày tăng dần, rồi tên tiệm, rồi tổng — xác định, không phụ
    thuộc thứ tự kho."""
    matched = [r for r in receipts if matches(r, kind, d_from, d_to)]
    matched.sort(key=lambda r: (r.day, r.vendor, r.total_cents or 0))

    entries = []
    missing_count = 0
    for rec in matched:
        files, missing_pages = loadable_files(rec, store)
        notes = []
        if rec.classification == "unknown":
            notes.append("chưa phân loại")
        if not files:
            notes.append("THIẾU BẢN GỐC")
            missing_count += 1
        elif missing_pages:
            notes.append(f"thiếu {missing_pages} trang gốc")
        entries.append([rec, files, "; ".join(notes)])

    # dedupe tên trên toàn ZIP theo thứ tự entries
    flat = [name for _, files, _ in entries for name, _ in files]
    deduped = dedupe_names(flat)
    i = 0
    for entry in entries:
        new_files = []
        for _, data in entry[1]:
            new_files.append((deduped[i], data))
            i += 1
        entry[1] = new_files

    total_sum = sum(r.total_cents or 0 for r in matched)
    summary = {"count": len(matched), "total_cents": total_sum,
               "missing": missing_count}

    # --- muc-luc.csv (UTF-8 BOM cho Excel) ---
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(["Ngày", "Tiệm", "Loại", "Mục", "Tạm tính", "Thuế",
                "Tổng", "Thẻ 4 số", "File bản gốc", "Ghi chú"])
    for rec, files, note in entries:
        w.writerow([
            rec.day.isoformat(), rec.vendor,
            CLASS_LABEL[rec.classification], rec.category,
            money_text(rec.subtotal_cents), money_text(rec.tax_cents),
            money_text(rec.total_cents), rec.card_last4 or "",
            ", ".join(n for n, _ in files), note,
        ])
    sub_sum = sum(r.subtotal_cents or 0 for r in matched)
    tax_sum = sum(r.tax_cents or 0 for r in matched)
    w.writerow(["", "TỔNG", FILTER_LABEL[kind] if kind != "all" else "Tất cả",
                "", money_text(sub_sum), money_text(tax_sum),
                money_text(total_sum), "", "",
                f"{len(matched)} tờ khớp · {missing_count} tờ thiếu bản gốc"])
    csv_bytes = b"\xef\xbb\xbf" + buf.getvalue().encode("utf-8")

    zip_name = (f"BanGoc-{FILTER_LABEL[kind]}-"
                f"{d_from.isoformat()}-{d_to.isoformat()}.zip")
    return {"summary": summary, "entries": entries,
            "csv_bytes": csv_bytes, "zip_name": zip_name}


def write_zip(export, store_note=""):
    """Ghi ZIP kiểu STORE (không nén thêm — JPEG/PDF đã nén sẵn),
    muc-luc.csv là thành viên cuối. Timestamp cố định trong gương để
    byte tái lập được; bản Swift chỉ cần đúng cấu trúc + store."""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_STORED) as z:
        for _, files, _ in export["entries"]:
            for name, data in files:
                info = zipfile.ZipInfo(name, date_time=(2025, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_STORED
                z.writestr(info, data)
        info = zipfile.ZipInfo("muc-luc.csv", date_time=(2025, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_STORED
        z.writestr(info, export["csv_bytes"])
    return buf.getvalue()
