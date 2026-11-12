import Foundation

// MARK: - M1 · SafeMoney — kiểu số tiền an toàn (CORE-V3, Pha 0)
//
// Đặc tả: DESIGN-DETAIL §2.0 (giữ nguyên văn ở DESIGN-FINAL §2) —
// sàn an toàn 5 điểm của crashfix (audit L-2026-11-11-8, đã kiểm
// chứng: parse giữ nguyên trên 20 bộ đầu vào; mô phỏng trap Int64
// PASS) nâng thành LUẬT MODULE. Đây là cửa chuyển đổi DUY NHẤT từ
// token OCR sang số tiền/qty cho mọi tầng của cốt lõi v3: cấm tự
// parse tiền ở nơi khác (bản đồ module M1 — DESIGN-DETAIL §1.2).
//
// Khác biệt CÓ CHỦ ĐÍCH so với sàn crashfix: ở đó moneyToCents trả
// 0 cho token không đọc được (hợp đồng cũ — 0 giả lẫn với 0 thật).
// §2.0 chốt hợp đồng mới: ngoài miền -> nil (coi như KHÔNG đọc
// được), tầng gọi phải gắn cờ, KHÔNG BAO GIỜ có 0 giả và KHÔNG BAO
// GIỜ trap.
//
// BẢN ĐỒ ÁNH XẠ — từng điểm sàn crashfix -> luật trong file này:
//   Điểm 1 (moneyToCents chặn đô-la ≤ 12 chữ số + xu đúng 2 chữ
//     số trước khi nhân 100; khử B1 tràn chuyển đổi và theo hệ quả
//     biên B3 tràn cộng dồn)
//     -> SafeMoney.parseCents (chặn tương đương + trả nil thay 0)
//     -> SafeMoney.sumCents (cộng dồn qua bao tràn — B3 khử thêm
//        một lớp nữa thay vì chỉ trông vào biên hệ quả)
//   Điểm 2 (lastCommaMoney chặn 12 chữ số cho phần nguyên; khử B4)
//     -> SafeMoney.parseCommaCents (đường phẩy thập phân riêng,
//        cùng chặn 12 chữ số như §2.0 yêu cầu)
//   Điểm 3 (matchQtyLine + matchQtyLineGeneric: qty ≤ 999_999;
//     khử B5)
//     -> SafeMoney.parseQty (mọi qty suy từ OCR đều qua cửa này)
//   Điểm 4 (anchorTotals bước 2: dạng chia `implied <= (15*s)/100`
//     thay `implied * 100 <= 15 * s`; khử B2)
//     -> SafeMoney.withinPercent (dạng chia + nhân kiểm-tra-tràn
//        ở tử số; fail-closed trả false khi tràn)
//   Điểm 5 (derivedOCRImage: chặn extent phái sinh — hữu hạn,
//     ≤ 4× mỗi chiều gốc, ≤ 64MP, ngoài biên -> không ứng viên)
//     -> KHÔNG thuộc file này (luật của M3 CaptureIntake, Pha 2);
//        cổng nền tảng của Pha 0 mô phỏng luật chặn đó trong
//        platform_gate.py Phần D để luật tồn tại dưới dạng kiểm
//        chạy được ngay từ Pha 0.
//   Cộng thêm ngoài 5 điểm (audit B7 + §2.0): regex tiền BIÊN
//   DỊCH MỘT LẦN (tokenRegex dưới đây) thay vì biên dịch lại mỗi
//   lần gọi như code cũ (hàng nghìn lần/tờ — chậm, không crash).
//
// Miền an toàn theo hệ quả biên (đã chứng minh ở crashfix): token
// qua cửa có |cents| ≤ 99_999_999_999_999 (~1e14); cộng dồn tối đa
// ~1e3 dòng -> ~1e17 << Int.max (9.2e18). Dù vậy MỌI phép tính vẫn
// đi qua bao kiểm tra tràn: biên hệ quả là lớp bảo vệ thứ hai,
// không phải lý do để bỏ lớp thứ nhất.

enum SafeMoney {

    // MARK: Biên miền (hằng số của luật — đổi là đổi thiết kế)

    /// Phần đô-la tối đa 12 chữ số (dưới $1 nghìn tỷ — cao hơn
    /// mọi hoá đơn thật nhiều bậc; crashfix B1).
    static let maxDollarDigits = 12
    /// Phần nguyên của dạng phẩy thập phân cùng chặn (crashfix B4).
    static let maxCommaWholeDigits = 12
    /// Số lượng tối đa nhận từ một token OCR (crashfix B5).
    static let maxQty = 999_999

    // MARK: Regex biên dịch một lần (audit B7)

    /// Mẫu token tiền của đường đọc cũ (`\d[\d,]*\.\d{2}` + dấu âm
    /// bám cuối kiểu Sam's) — biên dịch MỘT lần cho cả module.
    /// Token khớp mẫu này vẫn PHẢI qua parseCents mới thành tiền:
    /// mẫu không giới hạn độ dài dãy số, cửa miền nằm ở parseCents.
    static let tokenRegex: NSRegularExpression = {
        // Mẫu là hằng số hợp lệ — force-try ở đây không chạm dữ
        // liệu OCR (khác hẳn ép kiểu trên dữ liệu đọc được).
        try! NSRegularExpression(pattern: #"(\d[\d,]*\.\d{2})(-)?"#)
    }()

    /// Mọi token tiền (kèm cờ âm bám cuối) xuất hiện trong một
    /// dòng, theo thứ tự. Chỉ là TRÍCH TOKEN — chưa phải tiền.
    static func tokens(in line: String) -> [(token: String, negative: Bool)] {
        let range = NSRange(line.startIndex..., in: line)
        return tokenRegex.matches(in: line, options: [], range: range).compactMap { m in
            guard m.numberOfRanges >= 2,
                  let r = Range(m.range(at: 1), in: line) else { return nil }
            let negative = m.numberOfRanges >= 3
                && m.range(at: 2).location != NSNotFound
            return (String(line[r]), negative)
        }
    }

    /// Token tiền CUỐI cùng trong dòng (vị trí các hàm lá cũ như
    /// lastMoneyInLine vẫn cần) — vẫn là token thô, chưa qua cửa.
    static func lastToken(in line: String) -> (token: String, negative: Bool)? {
        tokens(in: line).last
    }

    // MARK: Cửa chuyển đổi — token -> cents

    /// "203.30" -> 20330 · "1,234.56" -> 123456 · "0.00" -> 0
    /// (0 THẬT — phân biệt được với nil). Ngoài miền -> nil:
    /// phần đô-la > 12 chữ số, phần xu khác đúng 2 chữ số, ký tự
    /// lạ, rỗng. Dấu âm qua cờ `negative` (kiểu in "4.50-" của
    /// Sam's) hoặc dấu "-" đứng đầu token đều nhận.
    static func parseCents(_ token: String, negative: Bool = false) -> Int? {
        var body = token.trimmingCharacters(in: .whitespaces)
        var neg = negative
        if body.hasPrefix("-") { neg = true; body.removeFirst() }
        if body.hasPrefix("$") { body.removeFirst() }
        let clean = body.replacingOccurrences(of: ",", with: "")
        let parts = clean.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let dollarsText = parts[0]
        let centsText = parts[1]
        guard !dollarsText.isEmpty,
              dollarsText.count <= maxDollarDigits,
              centsText.count == 2,
              dollarsText.allSatisfy({ $0.isNumber }),
              centsText.allSatisfy({ $0.isNumber }),
              let dollars = Int(dollarsText),
              let cents = Int(centsText) else { return nil }
        // dollars ≤ 999_999_999_999 nên nhân 100 không thể tràn;
        // vẫn đi qua bao kiểm tra tràn theo luật module (biên hệ
        // quả là lớp hai, không thay lớp một).
        guard let magnitude = checkedMultiply(dollars, by: 100),
              let value = checkedAdd(magnitude, cents) else { return nil }
        return neg ? -value : value
    }

    /// Đường phẩy thập phân RIÊNG (§2.0): dạng "$12,34" mà
    /// lastCommaMoney của đường cũ trích ra (phần nguyên + phần
    /// lẻ sau phẩy). Cùng chặn 12 chữ số cho phần nguyên; phần lẻ
    /// đúng 2 chữ số. Ngoài miền -> nil.
    static func parseCommaCents(whole: String, frac: String) -> Int? {
        guard !whole.isEmpty,
              whole.count <= maxCommaWholeDigits,
              frac.count == 2,
              whole.allSatisfy({ $0.isNumber }),
              frac.allSatisfy({ $0.isNumber }),
              let w = Int(whole),
              let f = Int(frac) else { return nil }
        guard let magnitude = checkedMultiply(w, by: 100),
              let value = checkedAdd(magnitude, f) else { return nil }
        return value
    }

    /// Số lượng từ token OCR: chỉ chữ số, ≤ maxQty. Token dài
    /// bất thường (> 18 chữ số — Int cũng không nuốt nổi) -> nil
    /// trước khi chuyển. Ngoài miền -> nil.
    static func parseQty(_ token: String) -> Int? {
        let body = token.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty,
              body.count <= 18,
              body.allSatisfy({ $0.isNumber }),
              let value = Int(body),
              value <= maxQty else { return nil }
        return value
    }

    // MARK: Số học có kiểm tra tràn (tràn -> nil, KHÔNG trap)

    static func checkedAdd(_ a: Int, _ b: Int) -> Int? {
        let r = a.addingReportingOverflow(b)
        return r.overflow ? nil : r.partialValue
    }

    static func checkedSubtract(_ a: Int, _ b: Int) -> Int? {
        let r = a.subtractingReportingOverflow(b)
        return r.overflow ? nil : r.partialValue
    }

    /// Nhân số-suy-từ-OCR với hằng số: qua multipliedReporting-
    /// Overflow — luật thay cho kỷ luật "chặn biên trước / viết
    /// lại dạng chia" của crashfix B2 ở những nơi dạng chia không
    /// tương đương (nơi tương đương được thì ưu tiên dạng chia —
    /// xem withinPercent).
    static func checkedMultiply(_ value: Int, by constant: Int) -> Int? {
        let r = value.multipliedReportingOverflow(by: constant)
        return r.overflow ? nil : r.partialValue
    }

    /// Cộng dồn một danh sách cents đã qua cửa (Σ món, Σ thuế).
    /// Tràn -> nil: tầng gọi coi tổng là KHÔNG DÙNG ĐƯỢC + gắn
    /// cờ, không bao giờ nhận một tổng đã tràn một phần.
    static func sumCents(_ values: [Int]) -> Int? {
        var acc = 0
        for v in values {
            guard let next = checkedAdd(acc, v) else { return nil }
            acc = next
        }
        return acc
    }

    /// Kiểm tỉ lệ của anchorTotals bước 2 ở DẠNG CHIA (crashfix
    /// điểm 4 — tương đương nguyên vẹn trên miền base > 0,
    /// implied ≥ 0; đã quét 200.000 cặp ở crashfix B4):
    ///     implied * 100 <= percent * base
    ///     ⇔  implied <= (percent * base) / 100
    /// Tử số percent * base đi qua bao tràn; tràn hoặc miền
    /// không hợp lệ (base ≤ 0, implied < 0) -> false (fail-
    /// closed: ứng viên KHÔNG được neo).
    static func withinPercent(implied: Int, ofBase base: Int, percent: Int) -> Bool {
        guard base > 0, implied >= 0, percent >= 0 else { return false }
        guard let scaled = checkedMultiply(percent, by: base) else { return false }
        return implied <= scaled / 100
    }
}
