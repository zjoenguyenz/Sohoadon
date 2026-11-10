#!/usr/bin/env python3
"""
Port Python TRUNG THỰC của F2b trong wp4-prep/Parser.swift (WP4 bước 2):
- parse_sams: vòng món (gồm luật hoàn tất món bằng dòng chỉ-có-tiền) +
  vòng tổng (máy trạng thái nhãn-chờ + các pattern cùng-dòng gốc).
- parse_generic: chỉ vòng tổng (máy trạng thái nhãn-chờ + pattern gốc +
  vùng loại trừ SUGGESTED TIP / RETURN POLICY).
validate(), findCard, findDate* KHÔNG port — F2b không đụng tới chúng;
bài kiểm đối chiếu số học bằng tay trong verify_f2b.py.
Regex Swift chạy case-insensitive (Parser.regex thêm .caseInsensitive)
nên port dùng re.IGNORECASE. Đây là kiểm THUẬT TOÁN parser trên dòng
chữ dựng sẵn — không phải OCR thật (WP4-SPEC.md).
"""
import re

FLAGS = re.IGNORECASE


def mg(text, pattern):
    """matchGroups: list nhóm bắt (None cho nhóm không tham gia) hoặc None."""
    m = re.search(pattern, text, FLAGS)
    if not m:
        return None
    return list(m.groups())


def money(s, negative):
    clean = s.replace(",", "")
    parts = clean.split(".")
    if len(parts) != 2:
        return 0
    v = int(parts[0]) * 100 + int(parts[1])
    return -v if negative else v


def trailing_amount(text):
    r"""trailingAmount: (\s)(\d[\d,]*\.\d{2})(-)?\s*([YT])?$ trên phần rest."""
    m = re.search(r"\s(\d[\d,]*\.\d{2})(-)?\s*([YT])?$", text, FLAGS)
    if not m:
        return None
    name = text[:m.start()].strip()
    return {"name": name, "cents": money(m.group(1), m.group(2) is not None),
            "flag": m.group(3)}


def match_qty_line(text):
    m = mg(text, r"^(\d+)\s+AT\s+1\s+FOR\s+(\d[\d,]*\.\d{2})(-)?\s+(\d[\d,]*\.\d{2})(-)?\s*([YT])?$")
    if m is None or len(m) != 6:
        return None
    return {"qty": int(m[0]), "unit": money(m[1], m[2] is not None),
            "amount": money(m[3], m[4] is not None), "flag": m[5]}


def last_money_in_line(text):
    ms = list(re.finditer(r"(\d[\d,]*\.\d{2})(-)?", text, FLAGS))
    if not ms:
        return None
    last = ms[-1]
    return money(last.group(1), last.group(2) is not None)


AMOUNT_ONLY = r"^\$?(\d[\d,]*\.\d{2})(-)?$"
AMOUNT_ONLY_ITEM = r"^\$?(\d[\d,]*\.\d{2})(-)?\s*([YT])?$"


def parse_sams(lines):
    r = {"items": [], "subtotal": None, "taxes": [], "total": None,
         "total_conf": 0.0, "items_sold": None, "dedupe": None}
    conf = {t: c for t, c in lines}
    texts = [t for t, _ in lines]

    # --- vòng món ---
    pending = None
    for text in texts:
        q = match_qty_line(text)
        if q is not None and pending is not None:
            pending["qty"] = q["qty"]
            pending["unit"] = q["unit"]
            pending["amount"] = q["amount"]
            if q["flag"]:
                pending["flag"] = q["flag"]
            r["items"].append(pending)
            pending = None
            continue
        # F2b: dòng chỉ-có-tiền hoàn tất món đang chờ
        m = mg(text, AMOUNT_ONLY_ITEM)
        if pending is not None and m is not None and len(m) == 3:
            cents = money(m[0], m[1] is not None)
            pending["amount"] = cents
            pending["unit"] = cents
            if m[2]:
                pending["flag"] = m[2]
            r["items"].append(pending)
            pending = None
            continue
        mp = mg(text, r"^INST SV\s+(.+)$")
        if mp is not None:
            rest = mp[0]
            tail = trailing_amount(rest)
            if tail:
                r["items"].append({"name": "INST SV " + tail["name"], "qty": 1,
                                   "unit": tail["cents"], "amount": tail["cents"],
                                   "flag": tail["flag"], "code": None})
            else:
                pending = {"name": "INST SV " + rest, "qty": 1, "unit": None,
                           "amount": None, "flag": None, "code": None}
            continue
        m = mg(text, r"^(\d{10})\s+(.+)$")
        if m is not None and len(m) == 2:
            code, rest = m[0], m[1]
            tail = trailing_amount(rest)
            if tail and tail["name"]:
                r["items"].append({"name": tail["name"], "qty": 1,
                                   "unit": tail["cents"], "amount": tail["cents"],
                                   "flag": tail["flag"], "code": code})
            else:
                pending = {"name": rest, "qty": 1, "unit": None,
                           "amount": None, "flag": None, "code": code}
            continue
    if pending is not None:
        r["items"].append(pending)

    # --- vòng tổng: F2b nhãn-chờ + pattern cùng-dòng gốc ---
    pending_kind = None
    pending_tax_label = None
    pending_tax_rate = None
    for text in texts:
        if pending_kind is not None:
            m = mg(text, AMOUNT_ONLY)
            if m is not None and len(m) == 2:
                cents = money(m[0], m[1] is not None)
                if pending_kind == "SUBTOTAL":
                    r["subtotal"] = cents
                elif pending_kind == "TOTAL":
                    r["total"] = cents
                    r["total_conf"] = conf[text]
                else:
                    r["taxes"].append({"label": pending_tax_label or "TAX",
                                       "rate": pending_tax_rate, "amount": cents})
                pending_kind = pending_tax_label = pending_tax_rate = None
                continue
        lm = mg(text, r"^(SUBTOTAL|TOTAL|TAX\s+(\d)(?:\s+([\d.]+)\s*%)?)$")
        if lm is not None and len(lm) == 3:
            head = lm[0]
            if head in ("SUBTOTAL", "TOTAL"):
                pending_kind = head
                pending_tax_label = pending_tax_rate = None
            else:
                pending_kind = "TAX"
                pending_tax_label = "TAX " + (lm[1] or "")
                pending_tax_rate = lm[2]
            continue
        pending_kind = pending_tax_label = pending_tax_rate = None
        m = mg(text, r"^SUBTOTAL\s+\$?(\d[\d,]*\.\d{2})(-)?$")
        if m is not None:
            r["subtotal"] = money(m[0], m[1] is not None)
            continue
        m = mg(text, r"^TAX\s+(\d)\s+([\d.]+)\s*%\s+\$?(\d[\d,]*\.\d{2})(-)?$")
        if m is not None and len(m) == 4:
            r["taxes"].append({"label": "TAX " + (m[0] or ""), "rate": m[1],
                               "amount": money(m[2], m[3] is not None)})
            continue
        m = mg(text, r"^TOTAL\s+\$?(\d[\d,]*\.\d{2})(-)?$")
        if m is not None:
            r["total"] = money(m[0], m[1] is not None)
            r["total_conf"] = conf[text]
            continue
        m = mg(text, r"^#\s*ITEMS SOLD\s+(\d+)$")
        if m is not None:
            r["items_sold"] = int(m[0])
            continue
        mp = mg(text, r"^TC#\s+([\d ]+)$")
        if mp is not None:
            digits = mp[0].replace(" ", "")
            if 16 <= len(digits) <= 24:
                r["dedupe"] = "SAMS-TC-" + digits
            continue
    return r


def parse_generic_totals(lines):
    """Chỉ vòng tổng của parseGeneric (đáp án cần cho bài kiểm F2b)."""
    r = {"subtotal": None, "taxes": [], "total": None}
    ignore_totals = False
    pending_kind = None
    for text, _conf in lines:
        upper = text.upper()
        # F2b: hoàn tất nhãn chờ bằng dòng chỉ-có-tiền
        if pending_kind is not None:
            m = mg(text, AMOUNT_ONLY)
            if m is not None and len(m) == 2:
                cents = money(m[0], m[1] is not None)
                if pending_kind == "SUBTOTAL":
                    if r["subtotal"] is None:
                        r["subtotal"] = cents
                elif pending_kind == "TOTAL":
                    if not ignore_totals and r["total"] is None:
                        r["total"] = cents
                else:
                    r["taxes"].append({"label": "TAX", "rate": None, "amount": cents})
                pending_kind = None
                continue
        if mg(text, r"^SUBTOTAL\s*:?$") is not None:
            pending_kind = "SUBTOTAL"
            continue
        if not ignore_totals and mg(text, r"^(TOTAL|TOTAL DUE|AMOUNT DUE|BALANCE DUE)\s*:?$") is not None:
            pending_kind = "TOTAL"
            continue
        if (upper.startswith("TAX") or upper.startswith("SALES TAX")) and last_money_in_line(text) is None:
            pending_kind = "TAX"
            continue
        pending_kind = None
        if "SUGGESTED TIP" in upper or "TIP GUIDE" in upper:
            ignore_totals = True
        if "RETURN POLICY" in upper or "MAX REFUND VALUE" in upper:
            continue
        m = mg(text, r"^SUBTOTAL\s*:?\s*\$?(\d[\d,]*\.\d{2})(-)?$")
        if m is not None:
            if r["subtotal"] is None:
                r["subtotal"] = money(m[0], m[1] is not None)
            continue
        is_tax = upper.startswith("TAX") or upper.startswith("SALES TAX")
        if is_tax:
            cents = last_money_in_line(text)
            if cents is not None:
                r["taxes"].append({"label": "TAX", "rate": None, "amount": cents})
                continue
        if not ignore_totals and r["total"] is None:
            m = mg(text, r"^(TOTAL|TOTAL DUE|AMOUNT DUE|BALANCE DUE)\s*:?\s*\$?(\d[\d,]*\.\d{2})(-)?$")
            if m is not None and len(m) == 3:
                r["total"] = money(m[1], m[2] is not None)
                continue
    return r
