import SwiftUI
import SwiftData

// MARK: - Huy hiệu phân loại: 4 tín hiệu cùng lúc (màu + icon + chữ + badge đuôi thẻ)

struct ClassificationBadge: View {
    var kind: Classification
    var cardLast4: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: kind.iconName)
            Text(kind.label)
            if let cardLast4, !cardLast4.isEmpty {
                Text("•• \(cardLast4)")
            }
        }
        .font(.caption.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(kind.color)
        .background(kind.color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Cửa chẩn đoán F3 (WP1): xem văn bản đọc thô — bằng chứng gốc khi đọc sai
//
// Một component dùng chung cho cả 2 màn (Kiểm Lại + Chi Tiết) để hành vi
// không lệch nhau: DisclosureGroup mặc định THU GỌN (không truyền
// isExpanded), chữ monospaced cỡ caption, chọn/copy được để anh gửi
// nguyên văn khi báo lỗi. `title` là tham số để WP3 (đường PDF) chỉ cần
// truyền nhãn "Văn bản trong PDF" ở 2 điểm gọi — không dựng lại viewer.
// WP1 chỉ có đường OCR nên cả 2 điểm gọi đều dùng nhãn OCR (mặc định).

/// WP3 bước 2 — QUYẾT NHÃN F3 (chốt ở cổng WP3): nhãn phải nói đúng
/// ĐƯỜNG nào sinh ra chữ (CODE-AUDIT F3 mục 3), không chỉ nguồn nạp:
/// lớp chữ PDF -> "Văn bản trong PDF"; PDF render->OCR -> "Văn bản OCR
/// gốc (từ PDF)"; mọi đường ảnh -> "Văn bản OCR gốc". Một helper dùng
/// chung cho Kiểm Lại (theo draft) và Chi Tiết (theo bản ghi đã lưu).
func rawTextTitle(sourceType: SourceType, isPDFTextLayer: Bool) -> String {
    if isPDFTextLayer { return "Văn bản trong PDF" }
    if sourceType == .pdfImport { return "Văn bản OCR gốc (từ PDF)" }
    return "Văn bản OCR gốc"
}

struct RawTextDisclosure: View {
    var text: String
    var title: String = "Văn bản OCR gốc"

    var body: some View {
        DisclosureGroup(title) {
            Text(text)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}

// MARK: - WP2 bước 2: dấu phiên bản bộ đọc (ACCOUNTING-SPEC F4, mức tối thiểu)
//
// Mọi hoá đơn lưu qua ReviewView.save() đều đóng dấu này vào
// Receipt.parserVersion, để sau này biết bản ghi nào do bộ đọc nào sinh ra
// khi đối chiếu lỗi đọc. Giá trị hiện tại = bộ đọc Build 1 (ReceiptParser
// chưa đổi ở WP2); WP4 (thi đấu engine) thắng/thua xong thì cập nhật
// hằng này cùng lúc thay engine — không sửa ngược bản ghi cũ.
//
// REPARSE (2026-11-10): hằng này THỰC SỰ được nâng lần đầu — các engine
// WP4/WP5/M1-FIX đã thay nhau trên main mà dấu vẫn nằm ở "build1-parser"
// (nợ ghi nhận ở cổng WP5), nên MỌI bản ghi hiện có (kể cả bản ghi do
// bản M1 lưu) đều mang dấu cũ hoặc rỗng. Giá trị mới "m1fix-reparse-1"
// là mã duy nhất của thế hệ bộ đọc WP5 + M1-FIX + điểm vào reparse;
// nút "Đọc lại" ở màn Chi Tiết dùng phép so parserVersion != hằng này
// (cộng điều kiện status == needsReview) để nhận diện tờ "cũ". Đọc lại
// một tờ đã mang dấu hiện hành cho kết quả số y hệt (cùng bộ đọc) —
// phép so chỉ quyết định nút có hiện hay không, không đổi số.

let currentParserVersion = "m1fix-reparse-1"

// MARK: - WP5 bước 3: nhãn nguồn tên tiệm (WP5-SPEC mục 3/4)
//
// ParseResult.vendorSource là mã máy của identifyVendor ("tier1-exact" |
// "tier1-fuzzy" | "tier2-anchor"); màn Kiểm Lại dịch ra chữ cho anh biết
// tên tiệm đến từ bằng chứng nào. Giá trị lạ/không có -> nil (không hiện
// nhãn bịa). Chỉ hiển thị — không nơi nào ghi nhãn này xuống model (model
// WP2 không có trường nguồn tiệm; độ tin cậy đã nằm ở vendorConfidence
// và kỷ luật Hộp Chờ đi qua warnings như cũ).

func vendorSourceText(_ source: String?) -> String? {
    switch source {
    case "tier1-exact":
        return "Nguồn tên tiệm: khớp tên in trên hoá đơn."
    case "tier1-fuzzy":
        return "Nguồn tên tiệm: khớp mờ tên in trên hoá đơn — anh kiểm tra giúp."
    case "tier2-anchor":
        return "Nguồn tên tiệm: nhận qua địa chỉ/số điện thoại — anh kiểm tra giúp."
    default:
        return nil
    }
}

// MARK: - Cờ kiểm tra lại trên 1 hoá đơn đã lưu (chỉ hiển thị, không sửa số)

func receiptFlags(_ receipt: Receipt) -> [String] {
    var flags: [String] = []
    if let subtotal = receipt.subtotalCents, !receipt.items.isEmpty {
        let sum = receipt.items.reduce(0) { $0 + ($1.amountCents ?? 0) }
        if abs(sum - subtotal) > 2 {
            flags.append("Tổng các món (\(formatMoney(cents: sum))) khác subtotal (\(formatMoney(cents: subtotal)))")
        }
    }
    if let subtotal = receipt.subtotalCents, let total = receipt.totalCents {
        let tax = receipt.taxCents ?? 0
        if abs(subtotal + tax - total) > 2 {
            flags.append("Subtotal + thuế khác tổng tiền")
        }
    }
    if receipt.totalCents == nil {
        flags.append("Thiếu tổng tiền")
    }
    if receipt.classification == .business && receipt.businessPurpose.trimmingCharacters(in: .whitespaces).isEmpty {
        flags.append("Thiếu mục đích business — sở thuế hay soi điểm này")
    }
    if receipt.classification == .unknown {
        flags.append("Chưa phân loại Cá nhân / Business")
    }
    return flags
}

// MARK: - Dòng hoá đơn trong danh sách

struct ReceiptRowView: View {
    var receipt: Receipt

    var body: some View {
        HStack(spacing: 12) {
            if let image = ImageStore.load(fileName: receipt.imageFileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "doc.text")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 56)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.vendor.isEmpty ? "(Chưa rõ tiệm)" : receipt.vendor)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(receipt.date, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ClassificationBadge(kind: receipt.classification, cardLast4: receipt.cardLast4)
                    if receipt.status == .needsReview {
                        Text("Chờ duyệt")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
            Text(formatMoney(optionalCents: receipt.totalCents))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Danh sách hoá đơn (gom theo tháng, có tổng chạy theo bộ lọc)

struct ReceiptListView: View {
    var onlyNeedsReview: Bool = false

    @Query(sort: \Receipt.date, order: .reverse) private var receipts: [Receipt]
    @State private var searchText = ""
    @State private var kindFilter: Classification? = nil

    private var filtered: [Receipt] {
        receipts.filter { receipt in
            if onlyNeedsReview && receipt.status != .needsReview { return false }
            if let kindFilter, receipt.classification != kindFilter { return false }
            if !searchText.isEmpty {
                let needle = searchText.lowercased()
                let inVendor = receipt.vendor.lowercased().contains(needle)
                let inCategory = receipt.category.lowercased().contains(needle)
                let inItems = receipt.items.contains { $0.name.lowercased().contains(needle) }
                let inText = receipt.ocrRawText.lowercased().contains(needle)
                if !(inVendor || inCategory || inItems || inText) { return false }
            }
            return true
        }
    }

    private var monthGroups: [(key: String, title: String, items: [Receipt])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { receipt -> DateComponents in
            calendar.dateComponents([.year, .month], from: receipt.date)
        }
        return grouped.keys
            .sorted { a, b in
                if (a.year ?? 0) != (b.year ?? 0) { return (a.year ?? 0) > (b.year ?? 0) }
                return (a.month ?? 0) > (b.month ?? 0)
            }
            .map { comps in
                let items = (grouped[comps] ?? []).sorted { $0.date > $1.date }
                let title = "Tháng \(comps.month ?? 0)/\(comps.year ?? 0)"
                let key = "\(comps.year ?? 0)-\(comps.month ?? 0)"
                return (key: key, title: title, items: items)
            }
    }

    private func sum(of kind: Classification, in items: [Receipt]) -> Int {
        items.filter { $0.classification == kind }.reduce(0) { $0 + ($1.totalCents ?? 0) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Running total của đúng tập đang lọc/tìm (chuẩn Copilot Money).
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tổng \(filtered.count) hoá đơn đang hiện")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 14) {
                            Label(formatMoney(cents: sum(of: .personal, in: filtered)), systemImage: "person.fill")
                                .foregroundStyle(Theme.personalColor)
                            Label(formatMoney(cents: sum(of: .business, in: filtered)), systemImage: "briefcase.fill")
                                .foregroundStyle(Theme.businessColor)
                        }
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        if sum(of: .unknown, in: filtered) != 0 {
                            Text("Chưa rõ: \(formatMoney(cents: sum(of: .unknown, in: filtered)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                ForEach(monthGroups, id: \.key) { group in
                    Section {
                        ForEach(group.items) { receipt in
                            NavigationLink {
                                ReceiptDetailView(receipt: receipt)
                            } label: {
                                ReceiptRowView(receipt: receipt)
                            }
                        }
                    } header: {
                        HStack {
                            Text(group.title)
                            Spacer()
                            Text("\(formatMoney(cents: sum(of: .personal, in: group.items))) · \(formatMoney(cents: sum(of: .business, in: group.items)))")
                                .monospacedDigit()
                        }
                    }
                }
            }
            .overlay {
                if filtered.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: onlyNeedsReview ? "checkmark.circle" : "doc.text.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(onlyNeedsReview ? "Đã phân loại xong hết ✓" : "Chưa có hoá đơn nào khớp")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(onlyNeedsReview ? "Hộp Chờ Duyệt" : "Hoá Đơn")
            .searchable(text: $searchText, prompt: "Tìm tiệm, món, mục…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Tất cả") { kindFilter = nil }
                        Button("Cá nhân") { kindFilter = .personal }
                        Button("Business") { kindFilter = .business }
                        Button("Chưa rõ") { kindFilter = .unknown }
                    } label: {
                        Label("Lọc", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }
}

// MARK: - Chi tiết hoá đơn

struct ReceiptDetailView: View {
    var receipt: Receipt

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    // REPARSE: cần danh sách đuôi thẻ để áp gợi ý phân loại đúng như
    // ReviewView.save() khi tờ CHƯA từng có quyết định phân loại.
    @Query private var cardTails: [CardTail]
    @State private var selectedKind: Classification
    @State private var selectedCategory: String
    @State private var purposeText: String
    @State private var showDeleteConfirm = false
    @State private var savedNote = false
    @State private var reparsedNote = false

    init(receipt: Receipt) {
        self.receipt = receipt
        _selectedKind = State(initialValue: receipt.classification)
        _selectedCategory = State(initialValue: receipt.category)
        _purposeText = State(initialValue: receipt.businessPurpose)
    }

    private var categoryOptions: [String] {
        var options = Categories.list(for: selectedKind)
        if !selectedCategory.isEmpty && !options.contains(selectedCategory) {
            options.append(selectedCategory)
        }
        return options
    }

    // REPARSE: nút "Đọc lại" chỉ hiện khi còn gì để đọc lại (có văn bản
    // thô đã lưu) VÀ tờ thuộc thế hệ bộ đọc cũ (dấu parserVersion khác
    // bản hiện hành — gồm cả dấu rỗng của bản ghi trước WP2) hoặc tờ
    // vẫn đang nằm ở Hộp Chờ. Tờ đã duyệt + dấu hiện hành thì không
    // hiện: đọc lại không thêm thông tin gì cho nó.
    private var canReparse: Bool {
        !receipt.ocrRawText.isEmpty
            && (receipt.parserVersion != currentParserVersion
                || receipt.status == .needsReview)
    }

    var body: some View {
        List {
            if let image = ImageStore.load(fileName: receipt.imageFileName) {
                Section("Ảnh gốc (bằng chứng)") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 320)
                        .frame(maxWidth: .infinity)
                }
            }

            Section("Thông tin") {
                LabeledContent("Tiệm", value: receipt.vendor.isEmpty ? "—" : receipt.vendor)
                // WP5 bước 3: bằng chứng liên hệ tiệm ĐÃ LƯU (model WP2) —
                // chỉ hiện khi có dữ liệu; bản ghi cũ (trước WP5) để trống
                // nên không đổi hành vi hiển thị.
                if !receipt.vendorAddress.isEmpty {
                    LabeledContent("Địa chỉ tiệm", value: receipt.vendorAddress)
                }
                if let phone = receipt.vendorPhone {
                    LabeledContent("Điện thoại tiệm", value: phone)
                }
                if let store = receipt.storeNumber {
                    LabeledContent("Mã cửa hàng", value: store)
                }
                LabeledContent("Ngày") {
                    Text(receipt.date, format: .dateTime.day().month().year().hour().minute())
                }
                LabeledContent("Subtotal") { moneyText(receipt.subtotalCents) }
                // WP2 bước 2: có dòng thuế riêng (taxLines) thì hiện TỪNG dòng
                // như in trên giấy (nhãn + thuế suất) + dòng tổng thuế lấy từ
                // helper taxTotalCents; chưa có thì giữ nguyên dòng thuế gộp
                // của Build 1 (bản ghi cũ không đổi hành vi hiển thị).
                if receipt.taxLines.isEmpty {
                    LabeledContent("Thuế") { moneyText(receipt.taxCents) }
                } else {
                    ForEach(receipt.taxLines.sorted { $0.sortIndex < $1.sortIndex }) { line in
                        LabeledContent(line.label + (line.rateText.map { " (\($0)%)" } ?? "")) {
                            moneyText(line.amountCents)
                        }
                    }
                    LabeledContent("Thuế (tổng)") { moneyText(receipt.taxTotalCents) }
                }
                LabeledContent("TỔNG") { moneyText(receipt.totalCents).bold() }
                if let last4 = receipt.cardLast4 {
                    LabeledContent("Thẻ", value: "\(receipt.cardBrand ?? "Thẻ") •• \(last4)")
                }
                if let key = receipt.dedupeKey {
                    LabeledContent("Mã chống trùng") {
                        Text(key).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            // REPARSE: đọc lại tờ cũ bằng bộ đọc hiện hành, cập nhật số
            // TẠI CHỖ trên chính bản ghi này (xem reparseReceipt()).
            if canReparse {
                Section("Bộ đọc") {
                    Button { reparseReceipt() } label: {
                        Label("Đọc lại bằng bộ đọc hiện tại", systemImage: "arrow.clockwise")
                    }
                    Text("Tờ này do \(receipt.parserVersion.isEmpty ? "bộ đọc đời đầu" : "bộ đọc \(receipt.parserVersion)") sinh ra; bộ đọc hiện tại là \(currentParserVersion). Đọc lại chạy bộ đọc hiện tại trên văn bản đã lưu và cập nhật số tại chỗ. Phân loại anh đã chọn và ghi chú mục đích được giữ nguyên.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if reparsedNote {
                        Text("Đã đọc lại ✓ — số đã cập nhật theo bộ đọc hiện tại")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            // F3 (WP1): văn bản đọc thô đã lưu — chỉ hiện khi có chữ (CODE-AUDIT
            // F3 mục 2). WP3 đóng F3 mục 3: nhãn trung thực theo nguồn —
            // hoá đơn nạp từ PDF lớp chữ thì ghi "Văn bản trong PDF", còn
            // lại là "Văn bản OCR gốc" (mặc định của component).
            if !receipt.ocrRawText.isEmpty {
                Section {
                    RawTextDisclosure(text: receipt.ocrRawText,
                                      title: rawTextTitle(sourceType: receipt.sourceType,
                                                           isPDFTextLayer: receipt.rawTextFromPDFTextLayer))
                }
            }

            let flags = receiptFlags(receipt)
            if !flags.isEmpty {
                Section("Cần kiểm lại") {
                    ForEach(flags, id: \.self) { flag in
                        Label(flag, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("Phân loại") {
                ClassificationBadge(kind: receipt.classification, cardLast4: receipt.cardLast4)
                if !receipt.classificationReason.isEmpty {
                    Text(receipt.classificationReason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker("Loại", selection: $selectedKind) {
                    Text("CÁ NHÂN").tag(Classification.personal)
                    Text("BUSINESS").tag(Classification.business)
                    Text("CHƯA RÕ").tag(Classification.unknown)
                }
                .pickerStyle(.segmented)
                Picker("Mục", selection: $selectedCategory) {
                    ForEach(categoryOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                if selectedKind == .business {
                    TextField("Mục đích business (mua để làm gì)", text: $purposeText, axis: .vertical)
                }
                Button("Lưu thay đổi") { saveChanges() }
                if savedNote {
                    Text("Đã lưu ✓").font(.caption).foregroundStyle(.green)
                }
            }

            if !receipt.items.isEmpty {
                Section("Từng món (\(receipt.items.count))") {
                    ForEach(receipt.items.sorted { $0.sortIndex < $1.sortIndex }) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(.callout)
                                Text("SL \(item.qty)" + (item.taxFlag.map { " · cờ \($0)" } ?? ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(formatMoney(optionalCents: item.amountCents))
                                .font(.callout)
                                .monospacedDigit()
                        }
                    }
                }
            }

            Section {
                if receipt.status == .needsReview {
                    Button {
                        receipt.status = .reviewed
                        try? modelContext.save()
                    } label: {
                        Label("Duyệt — đã kiểm, cho vào sổ chính thức", systemImage: "checkmark.circle.fill")
                    }
                } else {
                    Label("Đã duyệt ✓", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Xoá hoá đơn này", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Chi Tiết Hoá Đơn")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Xoá hẳn hoá đơn này và ảnh gốc?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Xoá", role: .destructive) {
                ImageStore.delete(fileName: receipt.imageFileName)
                modelContext.delete(receipt)
                try? modelContext.save()
                dismiss()
            }
            Button("Huỷ", role: .cancel) {}
        }
    }

    private func moneyText(_ cents: Int?) -> Text {
        Text(formatMoney(optionalCents: cents)).monospacedDigit()
    }

    // REPARSE: hạ cánh kết quả đọc lại vào CHÍNH bản ghi này, theo đúng
    // ánh xạ ReviewView.save() dùng cho hoá đơn mới — trừ các điểm giữ
    // nguyên quyết định/bằng chứng của người dùng (ghi rõ từng điểm):
    //
    // CẬP NHẬT (máy đọc): vendor + địa chỉ/điện thoại/mã cửa hàng, ngày
    // (chỉ khi bộ đọc tìm thấy — save() ghi ngày anh chốt trên lịch;
    // đọc lại không có lịch nên KHÔNG bao giờ ghi đè ngày đã lưu bằng
    // "hôm nay" khi bộ đọc trượt), subtotal/thuế/tổng, items và
    // taxLines (thay cả cụm), thẻ + paymentMethod, 3 độ tin cậy,
    // dedupeKey (chỉ khi bộ đọc sinh được khoá mới — không xoá khoá cũ
    // khi bộ đọc trượt), parserVersion -> bản hiện hành, status tính
    // lại đúng công thức save().
    //
    // GIỮ NGUYÊN (người dùng/bằng chứng): stableID, createdAt,
    // imageFileName + originalImageFileNames (ảnh gốc), sourceType +
    // sourceFileName, transactionRef (save() suy nó từ dedupeKey cho
    // bản ghi MỚI; bản ghi cũ giữ mã giao dịch đã lưu, không suy lại),
    // ocrRawText (chính là đầu vào của lần đọc này — bằng chứng gốc,
    // không ghi đè bằng bản đã chuẩn hoá của parser), businessPurpose,
    // và phân loại + mục nếu anh ĐÃ có quyết định (xem dưới).
    private func reparseReceipt() {
        let result = ReceiptParser.reparse(storedText: receipt.ocrRawText)

        // --- Trường máy đọc, ánh xạ như save() ---
        receipt.vendor = result.vendor ?? ""
        receipt.vendorAddress = result.vendorAddress ?? ""
        receipt.vendorPhone = result.vendorPhone
        receipt.storeNumber = result.storeNumber
        if let date = result.date {
            receipt.date = date
        }
        receipt.subtotalCents = result.subtotalCents
        receipt.totalCents = result.totalCents
        // Dòng thuế riêng theo đúng luật WP2 của save(): chỉ lưu chi
        // tiết dòng khi tổng thuế "đã duyệt" khớp Σ dòng máy đọc. Đọc
        // lại không có tay anh sửa giữa chừng, nên tổng đã duyệt chính
        // là Σ dòng của bộ đọc -> có dòng thuế thì lưu cả cụm và
        // taxCents = Σ dòng; không có dòng nào thì taxCents = nil
        // (chưa đọc được) như save() khi ô thuế để trống — không gộp
        // hai nghĩa nil/0.
        let persistTaxLines = !result.taxes.isEmpty
        receipt.taxCents = persistTaxLines ? result.taxTotalCents : nil
        let oldTaxLines = receipt.taxLines
        for line in oldTaxLines { modelContext.delete(line) }
        if persistTaxLines {
            for (index, parsedTax) in result.taxes.enumerated() {
                let line = TaxLine()
                line.label = parsedTax.label
                line.rateText = parsedTax.rateText
                line.amountCents = parsedTax.amountCents
                line.sortIndex = index
                line.receipt = receipt
                modelContext.insert(line)
            }
        }
        // Items: thay cả cụm như taxLines (bản ghi cũ giữ items của bộ
        // đọc cũ sẽ lẫn hai thế hệ số trong cùng một tờ).
        let oldItems = receipt.items
        for item in oldItems { modelContext.delete(item) }
        for (index, parsed) in result.items.enumerated() {
            let item = LineItem()
            item.name = parsed.name
            item.qty = parsed.qty
            item.unitPriceCents = parsed.unitPriceCents
            item.amountCents = parsed.amountCents
            item.taxFlag = parsed.taxFlag
            item.itemCode = parsed.itemCode
            item.sortIndex = index
            item.receipt = receipt
            modelContext.insert(item)
        }
        receipt.cardLast4 = result.cardLast4
        receipt.cardBrand = result.cardBrand
        // Như save(): có đuôi thẻ -> trả bằng thẻ, không có -> .unknown,
        // không bao giờ đoán tiền mặt.
        receipt.paymentMethod = (result.cardLast4?.isEmpty == false) ? .card : .unknown
        if let key = result.dedupeKey {
            receipt.dedupeKey = key
        }
        receipt.vendorConfidence = result.vendorConfidence
        receipt.dateConfidence = result.dateConfidence
        receipt.totalConfidence = result.totalConfidence

        // --- Phân loại: quyết định của anh thắng gợi ý ---
        // Đã có quyết định (loại khác "chưa rõ", hoặc chính tay anh đổi
        // trong màn này) thì giữ nguyên loại + lý do + mục: snapshot
        // phân loại là của anh, kể cả khi sổ thẻ đã đổi về sau. Chưa có
        // quyết định nào thì áp gợi ý theo thẻ đúng như save() (kèm
        // chỉnh mục về mặc định của loại mới nếu mục cũ không thuộc
        // danh sách của loại đó — cùng luật applySuggestionOnce).
        let userDecided = receipt.classification != .unknown
            || receipt.classificationReason == "Anh đổi tay trong chi tiết hoá đơn"
        if !userDecided {
            let suggestion = suggestClassification(cardLast4: result.cardLast4,
                                                   cardBrand: result.cardBrand,
                                                   tails: cardTails)
            receipt.classification = suggestion.0
            receipt.classificationReason = suggestion.1
            if !Categories.list(for: receipt.classification).contains(receipt.category) {
                receipt.category = Categories.defaultValue(for: receipt.classification)
            }
        }

        // --- Trạng thái: đúng công thức Hộp Chờ của save() ---
        let stillNeedsReview = receipt.classification == .unknown
            || receipt.totalCents == nil
            || !result.warnings.isEmpty
            || (receipt.classification == .business
                && receipt.businessPurpose.trimmingCharacters(in: .whitespaces).isEmpty)
        receipt.status = stillNeedsReview ? .needsReview : .reviewed
        receipt.parserVersion = currentParserVersion

        try? modelContext.save()
        // Vẽ lại theo số mới: đồng bộ 3 state của khối Phân loại về đúng
        // giá trị vừa hạ cánh (kể cả khi gợi ý vừa đổi loại/mục).
        selectedKind = receipt.classification
        selectedCategory = receipt.category
        purposeText = receipt.businessPurpose
        reparsedNote = true
    }

    private func saveChanges() {
        let kindChanged = selectedKind != receipt.classification
        receipt.classification = selectedKind
        if kindChanged {
            receipt.classificationReason = "Anh đổi tay trong chi tiết hoá đơn"
        }
        receipt.category = selectedCategory
        receipt.businessPurpose = purposeText
        try? modelContext.save()
        savedNote = true
    }
}

// MARK: - Màn Review sau khi quét (kiểm / sửa / lưu)

struct ReviewView: View {
    var draft: ScanDraft
    var onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var cardTails: [CardTail]

    @State private var vendorText: String
    @State private var dateValue: Date
    @State private var subtotalText: String
    @State private var taxText: String
    @State private var totalText: String
    @State private var selectedKind: Classification = .unknown
    @State private var reasonText: String = ""
    @State private var selectedCategory: String
    @State private var purposeText: String = ""
    @State private var suggestionApplied = false
    @State private var showDuplicateAlert = false
    @State private var duplicateCount = 0

    init(draft: ScanDraft, onDone: @escaping () -> Void) {
        self.draft = draft
        self.onDone = onDone
        let r = draft.result
        _vendorText = State(initialValue: r.vendor ?? "")
        _dateValue = State(initialValue: r.date ?? Date())
        _subtotalText = State(initialValue: centsToDollarsText(r.subtotalCents))
        _taxText = State(initialValue: r.taxes.isEmpty ? "" : centsToDollarsText(r.taxTotalCents))
        _totalText = State(initialValue: centsToDollarsText(r.totalCents))
        _selectedCategory = State(initialValue: Categories.defaultValue(for: .unknown))
    }

    private var categoryOptions: [String] {
        var options = Categories.list(for: selectedKind)
        if !options.contains(selectedCategory) { options.append(selectedCategory) }
        return options
    }

    var body: some View {
        NavigationStack {
            List {
                if let image = ImageStore.load(fileName: draft.imageFileName) {
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                    }
                }

                // F3 (WP1): văn bản đọc thô ngay dưới bằng chứng gốc (CODE-AUDIT
                // F3 mục 1). Đường OCR luôn có chữ mới tạo được draft; đường PDF
                // lớp chữ cũng luôn có chữ (không có chữ thì đã rẽ render->OCR).
                // Vẫn giữ guard rỗng cho đối xứng với màn Chi Tiết.
                // WP3 đóng F3 mục 3: nhãn theo nguồn nạp như màn Chi Tiết.
                if !draft.result.rawText.isEmpty {
                    Section {
                        RawTextDisclosure(text: draft.result.rawText,
                                          title: rawTextTitle(sourceType: draft.sourceType,
                                                               isPDFTextLayer: draft.rawTextIsPDFTextLayer))
                    }
                }

                if !draft.result.warnings.isEmpty {
                    Section("Anh kiểm tra giúp") {
                        ForEach(draft.result.warnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle.fill")
                                .font(.callout)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("Thông tin đọc được") {
                    TextField("Tiệm / Vendor", text: $vendorText)
                    DatePicker("Ngày", selection: $dateValue, displayedComponents: [.date, .hourAndMinute])
                    HStack {
                        Text("Subtotal")
                        Spacer()
                        moneyField($subtotalText)
                    }
                    HStack {
                        Text("Thuế (Tax)")
                        Spacer()
                        moneyField($taxText)
                    }
                    HStack {
                        Text("TỔNG (Total)").bold()
                        Spacer()
                        moneyField($totalText)
                    }
                    if draft.result.totalConfidence > 0 {
                        Text("Độ tin cậy của tổng tiền: \(Int(draft.result.totalConfidence * 100))%")
                            .font(.caption)
                            .foregroundStyle(draft.result.totalConfidence < 0.85 ? .orange : .secondary)
                    }
                    // WP5 bước 3: nguồn tên tiệm + gợi ý nấc 3 (WP5-SPEC mục
                    // 3/5/6) — nhãn nhỏ dưới các số tiền, KHÔNG che số; cảnh
                    // báo chữ vẫn đi qua mục "Anh kiểm tra giúp" ở trên như
                    // cũ, khối này chỉ cho anh thấy tên tiệm ĐẾN TỪ ĐÂU và
                    // bằng chứng liên hệ trích được để đối chiếu khi sửa tay.
                    if let sourceText = vendorSourceText(draft.result.vendorSource) {
                        Text(sourceText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if draft.result.vendor == nil, let suggestion = draft.result.vendorSuggestion {
                        Text("Chưa rõ tiệm — gợi ý từ món đặc trưng: \(suggestion) (chưa tự điền; đúng thì anh gõ vào ô Tiệm ở trên).")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if let address = draft.result.vendorAddress {
                        LabeledContent("Địa chỉ đọc được", value: address)
                    }
                    if let phone = draft.result.vendorPhone {
                        LabeledContent("Điện thoại đọc được", value: phone)
                    }
                    if let store = draft.result.storeNumber {
                        LabeledContent("Mã cửa hàng", value: store)
                    }
                    if let last4 = draft.result.cardLast4 {
                        LabeledContent("Thẻ đọc được", value: "\(draft.result.cardBrand ?? "Thẻ") •• \(last4)")
                    } else {
                        LabeledContent("Thẻ đọc được", value: "Không thấy dòng thẻ")
                    }
                }

                Section("Phân loại — gợi ý theo thẻ, anh đổi được") {
                    if !reasonText.isEmpty {
                        Text(reasonText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Picker("Loại", selection: $selectedKind) {
                        Text("CÁ NHÂN").tag(Classification.personal)
                        Text("BUSINESS").tag(Classification.business)
                        Text("CHƯA RÕ").tag(Classification.unknown)
                    }
                    .pickerStyle(.segmented)
                    Picker("Mục", selection: $selectedCategory) {
                        ForEach(categoryOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    if selectedKind == .business {
                        TextField("Mục đích business (mua để làm gì)", text: $purposeText, axis: .vertical)
                    }
                }

                if !draft.result.items.isEmpty {
                    Section("Từng món đọc được (\(draft.result.items.count))") {
                        ForEach(Array(draft.result.items.enumerated()), id: \.offset) { _, item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.callout)
                                    Text("SL \(item.qty)" + (item.taxFlag.map { " · cờ \($0)" } ?? ""))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formatMoney(optionalCents: item.amountCents))
                                    .font(.callout)
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                Section {
                    Button { attemptSave() } label: {
                        Label("Lưu hoá đơn", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Button("Huỷ, không lưu") { onDone() }
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Kiểm Lại Hoá Đơn")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { applySuggestionOnce() }
            .alert("Có vẻ hoá đơn này đã có trong sổ", isPresented: $showDuplicateAlert) {
                Button("Vẫn lưu thêm") { save(ignoreDuplicate: true) }
                Button("Huỷ, không lưu", role: .cancel) {}
            } message: {
                Text("Mã chống trùng của tờ này khớp \(duplicateCount) hoá đơn đã lưu (cùng mã TC#). Anh kiểm tra kẻo tính trùng 2 lần.")
            }
        }
    }

    private func moneyField(_ binding: Binding<String>) -> some View {
        TextField("0.00", text: binding)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: 110)
    }

    private func applySuggestionOnce() {
        guard !suggestionApplied else { return }
        suggestionApplied = true
        let suggestion = suggestClassification(cardLast4: draft.result.cardLast4,
                                               cardBrand: draft.result.cardBrand,
                                               tails: cardTails)
        selectedKind = suggestion.0
        reasonText = suggestion.1
        if !Categories.list(for: selectedKind).contains(selectedCategory) {
            selectedCategory = Categories.defaultValue(for: selectedKind)
        }
        checkDuplicate()
    }

    private func checkDuplicate() {
        guard let key = draft.result.dedupeKey else { duplicateCount = 0; return }
        // Lọc trong bộ nhớ thay cho #Predicate so sánh String? — loại bỏ điểm
        // rủi ro biên dịch với macro predicate trên cột optional (đã xử lý khi duyệt).
        let all = (try? modelContext.fetch(FetchDescriptor<Receipt>())) ?? []
        duplicateCount = all.filter { $0.dedupeKey == key }.count
    }

    private func attemptSave() {
        checkDuplicate()
        if duplicateCount > 0 {
            showDuplicateAlert = true
        } else {
            save(ignoreDuplicate: false)
        }
    }

    private func save(ignoreDuplicate: Bool) {
        let receipt = Receipt()
        receipt.vendor = vendorText.trimmingCharacters(in: .whitespaces)
        receipt.date = dateValue
        receipt.subtotalCents = dollarsTextToCents(subtotalText)
        receipt.taxCents = dollarsTextToCents(taxText)
        receipt.totalCents = dollarsTextToCents(totalText)
        receipt.cardLast4 = draft.result.cardLast4
        receipt.cardBrand = draft.result.cardBrand
        receipt.classification = selectedKind
        receipt.classificationReason = reasonText
        receipt.category = selectedCategory
        receipt.businessPurpose = purposeText
        receipt.dedupeKey = draft.result.dedupeKey
        receipt.vendorConfidence = draft.result.vendorConfidence
        receipt.dateConfidence = draft.result.dateConfidence
        receipt.totalConfidence = draft.result.totalConfidence
        receipt.imageFileName = draft.imageFileName
        receipt.ocrRawText = draft.result.rawText
        // --- WP2 bước 2: nối dây các trường mới (WP2-GATE, việc còn lại #1) ---
        receipt.stableID = UUID().uuidString
        receipt.sourceType = draft.sourceType
        // Có đuôi thẻ đọc được -> trả bằng thẻ; không có -> .unknown.
        // TUYỆT ĐỐI không đoán .cash: "không thấy dòng thẻ" khác hẳn "trả tiền mặt".
        receipt.paymentMethod = (draft.result.cardLast4?.isEmpty == false) ? .card : .unknown
        // Mã giao dịch tách khỏi khoá chống trùng: dedupeKey dạng "SAMS-TC-<số>"
        // hoặc "TC-<số>" thì phần số chính là transactionRef; khoá yếu dạng
        // "GEN|..." không chứa mã giao dịch -> để nil, không bịa.
        if let key = draft.result.dedupeKey {
            if key.hasPrefix("SAMS-TC-") {
                receipt.transactionRef = String(key.dropFirst("SAMS-TC-".count))
            } else if key.hasPrefix("TC-") {
                receipt.transactionRef = String(key.dropFirst("TC-".count))
            }
        }
        receipt.parserVersion = currentParserVersion
        // --- WP3: nối dây nguồn nạp file ---
        // Tên file gốc anh đã chọn (chỉ đường Files mới có) + danh sách file
        // bằng chứng gốc: PDF nạp vào giữ file PDF nguyên byte trong
        // ReceiptImages và tên của nó nằm ở đây (kèm imageFileName khi lớp
        // chữ đọc thẳng). Đường camera/Photos: cả hai để trống/nil như cũ.
        receipt.sourceFileName = draft.sourceFileName
        receipt.originalImageFileNames = draft.originalFileNames
        receipt.rawTextFromPDFTextLayer = draft.rawTextIsPDFTextLayer
        // --- WP5 bước 3: nối dây hạ cánh tiệm (WP5-SPEC mục 4) ---
        // Địa chỉ/điện thoại/mã cửa hàng là bằng chứng TRÍCH NGUYÊN VĂN từ
        // giấy (extractVendorContact ở Parser) — lưu đúng như đọc được,
        // không suy từ tên tiệm anh sửa tay ở ô "Tiệm / Vendor" phía trên:
        // anh đổi tên tiệm thì địa chỉ trên giấy vẫn là địa chỉ trên giấy.
        // Model WP2: vendorAddress là String (mặc định "") nên nil của
        // ParseResult hạ cánh thành ""; hai trường còn lại optional khớp.
        receipt.vendorAddress = draft.result.vendorAddress ?? ""
        receipt.vendorPhone = draft.result.vendorPhone
        receipt.storeNumber = draft.result.storeNumber
        // Dòng thuế riêng: CHỈ lưu khi tổng thuế anh đã duyệt ở màn Kiểm Lại còn
        // khớp Σ dòng thuế máy đọc. Anh sửa lệch đi thì giữ tổng gộp (taxCents
        // ở trên) và KHÔNG lưu chi tiết dòng — lưu chi tiết cũ cạnh tổng mới sẽ
        // bịa ra cơ cấu thuế không còn đúng với số anh đã chốt.
        let persistTaxLines = !draft.result.taxes.isEmpty
            && dollarsTextToCents(taxText) == draft.result.taxTotalCents
        if persistTaxLines {
            // Đồng bộ ngược chân tương thích cho màn cũ: taxCents = Σ taxLines
            // (bằng đúng số anh đã duyệt theo điều kiện ở trên).
            receipt.taxCents = draft.result.taxTotalCents
        }
        // Kỷ luật Hộp Chờ: còn cảnh báo / chưa rõ loại / business thiếu mục đích
        // -> ở trạng thái chờ duyệt, chưa phải chứng từ chính thức.
        let stillNeedsReview = selectedKind == .unknown
            || receipt.totalCents == nil
            || !draft.result.warnings.isEmpty
            || (selectedKind == .business && purposeText.trimmingCharacters(in: .whitespaces).isEmpty)
        receipt.status = stillNeedsReview ? .needsReview : .reviewed

        modelContext.insert(receipt)
        for (index, parsed) in draft.result.items.enumerated() {
            let item = LineItem()
            item.name = parsed.name
            item.qty = parsed.qty
            item.unitPriceCents = parsed.unitPriceCents
            item.amountCents = parsed.amountCents
            item.taxFlag = parsed.taxFlag
            item.itemCode = parsed.itemCode
            item.sortIndex = index
            item.receipt = receipt
            modelContext.insert(item)
        }
        // WP2 bước 2: ghi các dòng thuế riêng (TaxLine) cùng quan hệ cascade
        // như LineItem — chỉ khi persistTaxLines đã chốt ở trên.
        if persistTaxLines {
            for (index, parsedTax) in draft.result.taxes.enumerated() {
                let line = TaxLine()
                line.label = parsedTax.label
                line.rateText = parsedTax.rateText
                line.amountCents = parsedTax.amountCents
                line.sortIndex = index
                line.receipt = receipt
                modelContext.insert(line)
            }
        }
        try? modelContext.save()
        onDone()
    }
}
