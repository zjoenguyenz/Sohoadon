# -*- coding: utf-8 -*-
"""BỘ CHẤM OFFLINE CHO BUỔI ĐO DUY NHẤT (gói BENCH-PREP, QA).

Đọc file JSON theo bench-prep/BENCH-JSON-SPEC.md (schema v1), chạy parser
ĐÓNG BĂNG (m1fix/port.py, port nguyên văn của app) trên pass role="final"
của từng (ảnh × cấu hình), chấm theo core-redo/ACCEPTANCE.md §2 (M1–M10 +
E1/E2/E3) và phán theo core-redo/ENGINE-REPORT.md §5.3/§5.4:

- Bảng điểm THEO LỚP (ô dạng × khó) — KHÔNG có điểm trung bình chung.
- Cổng cứng mỗi lớp: M9 = 0 và tổng (M1) + ngày (M2) đúng 100% số tờ.
- Cổng danh dự S-0: cấu hình phải đạt trọn bộ §F trên ca S-0 mới qua.
- "Thua lớp": vi phạm cổng cứng ở lớp đó, hoặc điểm chính của lớp kém
  cấu hình đối chứng (mặc định A0-current) quá 1 tờ.
- Quyết kiến trúc §5.4: qua cổng cứng mọi lớp + cổng S-0 + không thua lớp
  nào → ứng viên; chọn ứng viên có tổng điểm chính có trọng số cao nhất
  (×2 cho lớp khó THẬT: L1, L2-real, L5; ×1 còn lại, gồm ca tổng hợp).
- Kết cục C (§5.5): nếu có lớp khó thật mà MỌI cấu hình đều < 50% điểm
  chính ở lớp đó → in cảnh báo kết cục C.
- Làn LAB (origin="lab", chốt Leader 2026-11-11 — xem
  bench-prep/lab-assembly/LAB-ASSEMBLY-DECISION.md): ca WildReceipt
  KHÔNG chấm bằng sổ GT (nhãn không cho sổ món ngoài đáng tin) — bộ
  chấm chỉ ĐẾM số run lab có mặt trong file đo rồi bỏ qua: không vào
  lớp, không trọng số, không phán quyết, không sinh lỗi "thiếu đáp
  án". Ca lab chấm TAY theo hồ sơ LAB (đúng-hoặc-cờ đối chiếu nhãn
  nguyên văn + đẳng thức nội bộ) trong báo cáo buổi đo.

Cách chạy:  python3 bench_score.py <file-ket-qua.json> [--answers a.json]
Sổ đáp án mặc định nằm ngay trong file này (ANSWERS). --answers nạp thêm
hoặc ghi đè đáp án khi có ca mới được đóng băng (đáp án KHÔNG nằm trong
file đo — chống hậu kiểm, BENCH-JSON-SPEC §6.5).
"""
import argparse, importlib.util, json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
_spec = importlib.util.spec_from_file_location("port", ROOT / "m1fix" / "port.py")
port = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(port)

# ---------------------------------------------------------------- sổ đáp án
# Bộ số đóng băng từ ACCEPTANCE.md §2.5 / ground-truth 001-002-003.
# ledger_tol: dung sai E1/E2 (xu) — mẫu hạt giống = 0 theo §2.3; ca thật
# lớp C khi đóng băng sẽ ghi 2.
ANSWERS = {
    "GT-SAMS-F": {  # §F đầy đủ — dùng cho N-001, N-002, C-002C, S-0
        "vendor": "Sam's Club", "date": "2026-10-29", "time": "17:49",
        "subtotal": 20330, "taxes": [960, 390], "total": 21680,
        "items_count": 10, "items_sold": 15,
        "card_brand": "Mastercard", "card_last4": "2586",
        "ledger_tol": 0,
    },
    "GT-HD-003": {  # Mẫu 003 — The Home Depot
        "vendor": "The Home Depot", "date": "2025-03-03", "time": "12:59",
        "subtotal": 9691, "taxes": [825], "total": 10516,
        "items_count": 3, "items_sold": None,
        "card_brand": "Visa", "card_last4": "3830",
        "ledger_tol": 0,
    },
}

# Từ khoá cảnh báo (validate() của parser đóng băng) theo trường — dùng để
# phân định "sai CÓ cờ" vs "sai KHÔNG cờ" (M9) và cờ oan tin cậy (M10).
WARN_KEYS = {
    "total":    ["TỔNG TIỀN", "Tổng tiền", "subtotal + thuế"],
    "subtotal": ["tổng các món", "subtotal + thuế"],
    "taxes":    ["subtotal + thuế"],
    "date":     ["ngày", "Ngày"],
    "vendor":   ["tiệm", "Tên tiệm"],
    "ledger":   ["tổng các món", "subtotal + thuế"],
    "qty":      ["Số lượng"],
}
LOWCONF_KEY = "độ tin cậy THẤP"


def has_warn(warnings, field):
    keys = WARN_KEYS.get(field, [])
    return any(any(k in w for k in keys) for w in warnings)


def norm_vendor(s):
    if s is None:
        return None
    return " ".join(s.lower().replace("’", "'").split()).strip(" .")


def weight_of(img):
    """Trọng số §5.4.3: ×2 lớp khó THẬT (L1, L2, L5 — chỉ khi origin
    là real; ca tổng hợp và ca lab luôn ×1 dù difficulty gán lớp nào —
    chốt Leader 2026-11-10 sau cờ của gói BENCH-CATALOG-EXT, mở rộng
    cho origin=lab 2026-11-11). Ca lab thực tế không tới hàm này vì
    bị bỏ qua từ vòng chấm (xem docstring đầu file)."""
    d, o = img["difficulty"], img.get("origin", "real")
    if o != "real":
        return 1
    if d in ("L1", "L2", "L5"):
        return 2
    return 1


def is_hard_real(img):
    d, o = img["difficulty"], img.get("origin", "real")
    return o == "real" and d in ("L1", "L2", "L5")


def score_one(result, gt):
    """Chấm một kết quả parse (dict của port) đối chiếu một đáp án."""
    w = result["warnings"]
    m = {}
    # M1 tổng · M2 ngày(+giờ) · M3 tiệm · M7 thuế từng dòng · M8 thẻ
    m["M1"] = result["total"] == gt["total"]
    m["M2"] = (result["date"] is not None and result["date"][:10] == gt["date"]
               and (gt.get("time") is None or result["date"][11:16] == gt["time"]))
    m["M3"] = norm_vendor(result["vendor"]) == norm_vendor(gt["vendor"])
    m["M7"] = [t["amount"] for t in result["taxes"]] == gt["taxes"]
    m["M8"] = (result["cardLast4"] == gt["card_last4"]
               and result["cardBrand"] is not None
               and gt["card_brand"].lower() in result["cardBrand"].lower())
    # Ba đẳng thức (nội bộ parser + đối chiếu đáp án)
    tol = gt["ledger_tol"]
    sum_items = sum(i["amount"] or 0 for i in result["items"])
    qty_pos = sum(i["qty"] for i in result["items"] if (i["amount"] or 0) > 0)
    m["E1"] = (result["subtotal"] == gt["subtotal"]
               and abs(sum_items - gt["subtotal"]) <= tol)
    m["E2"] = (result["total"] == gt["total"]
               and result["subtotal"] is not None
               and abs(result["subtotal"] + sum(t["amount"] for t in result["taxes"])
                       - gt["total"]) <= tol)
    if gt["items_sold"] is None:
        m["E3"] = None  # hoá đơn không in số món — không chấm
    else:
        m["E3"] = (result["itemsSold"] == gt["items_sold"]
                   and qty_pos == gt["items_sold"])
    m["ledger_full"] = bool(m["E1"] and m["E2"] and (m["E3"] in (True, None))
                            and m["M7"])
    # M9: trường sai mà KHÔNG có cờ tương ứng (thiếu hẳn = parser có cảnh
    # báo "Không đọc được" → có cờ; sai giá trị + không cảnh báo liên quan
    # → vi phạm). M10: trường ĐÚNG mà bị cờ "độ tin cậy THẤP" oan.
    m9, m10 = [], []
    checks = [  # (tên trường, đúng?, khoá cảnh báo)
        ("total", m["M1"], "total"), ("date", m["M2"], "date"),
        ("vendor", m["M3"], "vendor"), ("taxes", m["M7"], "taxes"),
        ("subtotal", result["subtotal"] == gt["subtotal"], "subtotal"),
        ("ledger-E1", m["E1"], "ledger"), ("ledger-E2", m["E2"], "ledger"),
    ]
    if m["E3"] is not None:
        checks.append(("qty-E3", m["E3"], "qty"))
    for name, ok, key in checks:
        if not ok and not has_warn(w, key):
            m9.append(name)
        if ok and any(LOWCONF_KEY in x and any(k in x for k in WARN_KEYS[key])
                      for x in w):
            m10.append(name)
    m["M9"] = m9
    m["M10"] = m10
    m["detail"] = {"sum_items": sum_items, "qty_pos": qty_pos,
                    "n_items": len(result["items"]),
                    "parsed": {"vendor": result["vendor"], "date": result["date"],
                               "subtotal": result["subtotal"],
                               "taxes": [t["amount"] for t in result["taxes"]],
                               "total": result["total"],
                               "itemsSold": result["itemsSold"]}}
    return m


def full_section_f(m, gt):
    """Trọn bộ §F (cổng S-0 + lớp B): mọi trường cứng + sổ món trọn."""
    d = m["detail"]
    return bool(m["M1"] and m["M2"] and m["M3"] and m["M7"] and m["M8"]
                and m["ledger_full"] and d["n_items"] == gt["items_count"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("result_file")
    ap.add_argument("--answers", default=None)
    ap.add_argument("--baseline", default="A0-current")
    args = ap.parse_args()

    data = json.loads(pathlib.Path(args.result_file).read_text(encoding="utf-8"))
    if data.get("schema") != "sohoadon-bench" or data.get("schema_version") != 1:
        sys.exit("RỚT: file không đúng schema sohoadon-bench v1 "
                 "(BENCH-JSON-SPEC §6) — không chấm đoán.")
    answers = dict(ANSWERS)
    if args.answers:
        answers.update(json.loads(pathlib.Path(args.answers).read_text(encoding="utf-8")))

    images = {i["id"]: i for i in data["images"]}
    configs = [c["id"] for c in data["configs"]]
    baseline = args.baseline
    if any(c.get("baseline") for c in data["configs"]):
        baseline = [c["id"] for c in data["configs"] if c.get("baseline")][0]

    # rows[(config, image)] = metrics
    rows = {}
    errors = []
    lab_runs = 0
    lab_images = set()
    for run in data["runs"]:
        img = images.get(run["image_id"])
        if img is None:
            errors.append(f"run trỏ ảnh không có trong images: {run['image_id']}")
            continue
        if img.get("origin") == "lab":
            # Làn lab: đếm để báo cáo buổi đo biết ca đã chạy trên máy,
            # nhưng không chấm GT (quyết đã chốt — xem docstring đầu file).
            lab_runs += 1
            lab_images.add(img["id"])
            continue
        gt = answers.get(img["gt_id"])
        if gt is None:
            errors.append(f"không có đáp án cho gt_id={img['gt_id']} (ảnh {img['id']})")
            continue
        finals = [p for p in run["passes"] if p.get("role") == "final"]
        if len(finals) != 1:
            errors.append(f"{run['image_id']}×{run['config_id']}: có {len(finals)} "
                          "pass role=final (phải đúng 1) — không chấm run này")
            continue
        p = finals[0]
        lines = [(ln["text"], ln.get("confidence", 0.95)) for ln in p["lines"]]
        result = port.parse(lines, fixed=True)
        m = score_one(result, gt)
        m["duration_ms"] = p.get("duration_ms")
        m["sectionF"] = full_section_f(m, gt)
        rows[(run["config_id"], run["image_id"])] = m

    def layer_of(img_id):
        i = images[img_id]
        return f"{i['form']}/{i['difficulty']}"

    # Lớp chỉ từ các ca ĐÃ CHẤM (rows) — ca lab/ca lỗi không tạo lớp rỗng.
    layers = sorted({layer_of(img_id) for (_, img_id) in rows})
    print(f"== BẢNG ĐIỂM THEO LỚP — file: {args.result_file} ==")
    print(f"   (đối chứng: {baseline}; KHÔNG có điểm trung bình chung — "
          "mỗi lớp tự đứng)\n")
    if lab_runs:
        print(f"-- LÀN LAB (origin=lab): {lab_runs} run trên "
              f"{len(lab_images)} ca ({', '.join(sorted(lab_images))}) — "
              "KHÔNG chấm GT ở bộ chấm này; chấm tay theo hồ sơ LAB "
              "trong báo cáo buổi đo --")

    layer_main = {}   # (config, layer) -> (số tờ trọn sổ, tổng số tờ)
    hard_fail = {}    # (config, layer) -> [lý do]
    s0 = {}           # config -> True/False/None
    weighted = {c: 0 for c in configs}
    for c in configs:
        for img_id, img in images.items():
            m = rows.get((c, img_id))
            if m is None:
                continue
            lay = layer_of(img_id)
            a, b = layer_main.get((c, lay), (0, 0))
            layer_main[(c, lay)] = (a + (1 if m["ledger_full"] else 0), b + 1)
            reasons = []
            if m["M9"]:
                reasons.append("M9: số sai không cờ ở " + ", ".join(m["M9"]))
            if not m["M1"]:
                reasons.append("M1: tổng sai")
            if not m["M2"]:
                reasons.append("M2: ngày sai")
            if reasons:
                hard_fail.setdefault((c, lay), []).extend(
                    f"{img_id}: {r}" for r in reasons)
            weighted[c] += weight_of(img) * (1 if m["ledger_full"] else 0)
            if img_id == "S-0":
                s0[c] = m["sectionF"]

    for lay in layers:
        print(f"-- LỚP {lay} --")
        for c in configs:
            if (c, lay) not in layer_main:
                continue
            a, b = layer_main[(c, lay)]
            fails = hard_fail.get((c, lay), [])
            gate = "CỔNG CỨNG: RỚT (" + "; ".join(fails) + ")" if fails \
                else "CỔNG CỨNG: QUA"
            print(f"   {c:<14} trọn sổ món {a}/{b} tờ · {gate}")
        print()

    # Chi tiết từng ca cho các cấu hình (phục vụ phân định tầng khi rớt)
    print("-- CHI TIẾT TỪNG CA --")
    for (c, img_id), m in sorted(rows.items()):
        d = m["detail"]
        flags = []
        for k in ("M1", "M2", "M3", "M7", "M8", "E1", "E2", "E3"):
            if m[k] is False:
                flags.append(k + "✗")
        line = (f"   {c:<14} {img_id:<8} sổ={'ĐẠT' if m['ledger_full'] else 'TRƯỢT'}"
                f" §F={'ĐẠT' if m['sectionF'] else '—'}"
                f" Σmón={d['sum_items']} SL+={d['qty_pos']} dòng={d['n_items']}"
                f" {m['duration_ms']}ms")
        if flags:
            line += "  [" + " ".join(flags) + "]"
        if m["M9"]:
            line += "  M9={" + ", ".join(m["M9"]) + "}"
        if m["M10"]:
            line += "  M10(cờ oan)={" + ", ".join(m["M10"]) + "}"
        print(line)
    print()

    # Thua lớp so với đối chứng + phán quyết §5.4
    print("== PHÁN QUYẾT THEO ENGINE §5.4 ==")
    if baseline not in configs:
        print(f"   [CKBC] Không có cấu hình đối chứng '{baseline}' trong file "
              "— không tính được 'thua lớp', phán quyết dưới đây thiếu điều kiện 2.")
    losers = {}
    for c in configs:
        if c == baseline:
            continue
        lost = []
        for lay in layers:
            if (c, lay) not in layer_main or (baseline, lay) not in layer_main:
                continue
            a_c, _ = layer_main[(c, lay)]
            a_b, _ = layer_main[(baseline, lay)]
            if (baseline, lay) in hard_fail and (c, lay) not in hard_fail:
                continue
            if a_b - a_c > 1 or ((c, lay) in hard_fail and (baseline, lay) not in hard_fail):
                lost.append(lay)
        losers[c] = lost

    candidates = []
    for c in configs:
        gate_ok = all((c, lay) not in hard_fail for lay in layers
                      if (c, lay) in layer_main)
        s0_ok = s0.get(c, None)
        s0_pass = (s0_ok is not False)  # không có ca S-0 trong file → không kết án
        lost = losers.get(c, [])
        verdict = []
        if not gate_ok:
            verdict.append("RỚT cổng cứng")
        if s0_ok is False:
            verdict.append("RỚT cổng danh dự S-0")
        if lost:
            verdict.append("thua lớp: " + ", ".join(lost))
        status = "ỨNG VIÊN ENGINE-CORE" if not verdict else "; ".join(verdict)
        if not verdict:
            candidates.append(c)
        print(f"   {c:<14} điểm trọng số={weighted[c]} · {status}")
    if candidates:
        best = max(candidates, key=lambda c: weighted[c])
        print(f"   → CHỌN: {best} (điểm trọng số cao nhất trong các ứng viên) "
              "→ Kết cục A nếu mọi lớp đều có mẫu; lớp chưa có mẫu ghi CKBC.")
    else:
        print("   → Không cấu hình nào đủ điều kiện §5.4 → Kết cục B/C, "
              "trình anh theo ENGINE §5.5. CẤM giao như thể đã giải quyết.")
    # Kết cục C: lớp khó thật có mẫu mà mọi cấu hình < 50% điểm chính
    hard_layers = sorted({layer_of(i) for i in images.values() if is_hard_real(i)})
    for lay in hard_layers:
        rates = []
        for c in configs:
            if (c, lay) in layer_main:
                a, b = layer_main[(c, lay)]
                rates.append(a / b if b else 0)
        if rates and all(r < 0.5 for r in rates):
            print(f"   ⚠ KẾT CỤC C ở lớp {lay}: mọi cấu hình < 50% trọn sổ món "
              "— theo §5.5 phải kết luận thẳng bằng số đo, không giao bản.")
    if errors:
        print("\n== LỖI DỮ LIỆU ĐO (ca liên quan KHÔNG được chấm) ==")
        for e in errors:
            print("   -", e)


if __name__ == "__main__":
    main()
