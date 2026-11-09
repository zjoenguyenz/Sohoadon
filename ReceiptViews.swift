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
    @State private var selectedKind: Classification
    @State private var selectedCategory: String
    @State private var purposeText: String
    @State private var showDeleteConfirm = false
    @State private var savedNote = false

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
                LabeledContent("Ngày") {
                    Text(receipt.date, format: .dateTime.day().month().year().hour().minute())
                }
                LabeledContent("Subtotal") { moneyText(receipt.subtotalCents) }
                LabeledContent("Thuế") { moneyText(receipt.taxCents) }
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

            // F3 (WP1): văn bản OCR gốc đã lưu — chỉ hiện khi có chữ (CODE-AUDIT F3 mục 2).
            if !receipt.ocrRawText.isEmpty {
                Section {
                    RawTextDisclosure(text: receipt.ocrRawText)
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

                // F3 (WP1): văn bản OCR gốc ngay dưới ảnh gốc (CODE-AUDIT F3 mục 1).
                // Draft chỉ được tạo khi OCR có dòng chữ (ScanView.process chặn
                // lines.isEmpty) nên rawText luôn có nội dung; vẫn giữ guard
                // rỗng cho đối xứng với màn Chi Tiết.
                if !draft.result.rawText.isEmpty {
                    Section {
                        RawTextDisclosure(text: draft.result.rawText)
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
        try? modelContext.save()
        onDone()
    }
}
