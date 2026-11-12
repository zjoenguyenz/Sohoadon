import SwiftUI
import SwiftData

/// Tab "Thẻ & Cài Đặt":
/// - Đăng ký đuôi thẻ debit: thêm / sửa / NGƯNG (không xoá đuôi đã có hoá đơn).
///   Đổi loại 1 thẻ -> app hỏi rõ "chỉ từ nay, hay xếp lại hoá đơn cũ của thẻ này?".
/// - Cài Đặt: khoá Face ID, ghi chú lưu trữ.
struct CardsView: View {
    @Query(sort: \CardTail.createdAt) private var cardTails: [CardTail]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("faceIDLockEnabled") private var lockEnabled = true

    @State private var formTarget: CardFormTarget? = nil
    @State private var pendingKindChange: PendingKindChange? = nil
    /// N2-FIX: lưu thẻ thất bại — hiện alert, không nuốt lặng.
    @State private var saveFailed = false

    private var activeCards: [CardTail] { cardTails.filter { !$0.archived } }
    private var archivedCards: [CardTail] { cardTails.filter { $0.archived } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(activeCards) { card in
                        cardRow(card)
                    }
                } header: {
                    Text("Thẻ đang dùng")
                } footer: {
                    Text("App chỉ nhớ 4 số cuối + hãng thẻ — không bao giờ cần số thẻ đầy đủ. Đuôi thẻ là GỢI Ý phân loại, anh luôn đổi được từng hoá đơn.")
                }

                if !archivedCards.isEmpty {
                    Section("Thẻ đã ngưng dùng") {
                        ForEach(archivedCards) { card in
                            cardRow(card)
                        }
                    }
                }

                Section {
                    Button {
                        formTarget = .new
                    } label: {
                        Label("Thêm đuôi thẻ", systemImage: "plus.circle.fill")
                    }
                }

                Section("Cài Đặt") {
                    Toggle(isOn: $lockEnabled) {
                        Label("Khoá bằng Face ID", systemImage: "faceid")
                    }
                    Text("Bật khoá: mỗi lần mở app phải xác nhận Face ID hoặc mật mã máy. Máy không có Face ID/mật mã thì app mở bình thường, không khoá cứng.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LabeledContent("Nơi lưu ảnh gốc", value: "Trong app (Files → Sổ Hóa Đơn)")
                    LabeledContent("Đọc hoá đơn", value: "Ngay trên máy, không gửi ra ngoài")
                }
            }
            .navigationTitle("Thẻ & Cài Đặt")
            .sheet(item: $formTarget) { target in
                CardFormView(target: target, existingTails: cardTails) { data in
                    handleFormData(data)
                }
            }
            .alert("Lưu không thành công", isPresented: $saveFailed) {
                Button("Đã hiểu", role: .cancel) {}
            } message: {
                Text("Thay đổi thẻ CHƯA được lưu vào máy. Anh thử lại giúp — nếu vẫn không được, anh kiểm tra dung lượng trống của máy.")
            }
            .confirmationDialog(
                "Đổi loại thẻ •• \(pendingKindChange?.last4 ?? "")?",
                isPresented: Binding(
                    get: { pendingKindChange != nil },
                    set: { if !$0 { pendingKindChange = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Chỉ áp dụng từ nay") {
                    if let pending = pendingKindChange { applyCardChange(pending, reclassifyOld: false) }
                    pendingKindChange = nil
                }
                Button("Xếp lại cả hoá đơn cũ của thẻ này") {
                    if let pending = pendingKindChange { applyCardChange(pending, reclassifyOld: true) }
                    pendingKindChange = nil
                }
                Button("Huỷ", role: .cancel) { pendingKindChange = nil }
            } message: {
                Text("Hoá đơn cũ của thẻ này giữ nguyên phân loại đã lưu, trừ khi anh chọn xếp lại.")
            }
        }
    }

    // MARK: Dòng thẻ — vẽ như thẻ vật lý (học Apple Wallet)

    private func cardRow(_ card: CardTail) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(card.kind.color)
                    .frame(width: 86, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Image(systemName: card.kind.iconName)
                    Text("•• \(card.last4)")
                        .font(.caption.bold())
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .frame(width: 86, alignment: .leading)
                .padding(.leading, 10)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(card.brand.isEmpty ? "Thẻ" : card.brand)
                    .font(.body.weight(.semibold))
                Text(card.kind.label + (card.archived ? " · đã ngưng" : ""))
                    .font(.caption)
                    .foregroundStyle(card.kind.color)
            }
            Spacer()
            Menu {
                Button("Sửa thẻ") { formTarget = .edit(card) }
                if card.archived {
                    Button("Dùng lại thẻ này") { setArchived(card, false) }
                } else {
                    Button("Ngưng dùng thẻ này") { setArchived(card, true) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
        .opacity(card.archived ? 0.6 : 1.0)
    }

    private func setArchived(_ card: CardTail, _ archived: Bool) {
        // N2-FIX: lưu hỏng thì trả trạng thái cũ + báo thật;
        // bản cũ nuốt lỗi, thẻ trông như đã ngưng mà máy chưa ghi.
        let old = card.archived
        card.archived = archived
        if !saveContextOrFalse(modelContext) {
            card.archived = old
            saveFailed = true
        }
    }

    // MARK: Xử lý form thêm/sửa

    private func handleFormData(_ data: CardFormData) {
        if let card = data.existingCard {
            if card.kind != data.kind {
                // Đổi loại: không tự áp — hỏi anh trước qua confirmationDialog.
                pendingKindChange = PendingKindChange(card: card, brand: data.brand, kind: data.kind, last4: card.last4)
            } else {
                // N2-FIX: như setArchived — hỏng thì hoàn tác
                // trong bộ nhớ và báo thật.
                let oldBrand = card.brand
                card.brand = data.brand
                if !saveContextOrFalse(modelContext) {
                    card.brand = oldBrand
                    saveFailed = true
                }
            }
        } else {
            let card = CardTail()
            card.last4 = data.last4
            card.brand = data.brand
            card.kind = data.kind
            modelContext.insert(card)
            if !saveContextOrFalse(modelContext) {
                // Gỡ thẻ chưa lưu khỏi context — không để nó
                // tự hạ cánh ở một lần lưu khác sau này.
                modelContext.delete(card)
                saveFailed = true
            }
        }
    }

    private func applyCardChange(_ pending: PendingKindChange, reclassifyOld: Bool) {
        // N2-FIX: bản cũ `(try? fetch) ?? []` — đọc sổ lỗi thì
        // việc xếp lại hoá đơn cũ lặng lẽ thành không làm gì,
        // trong khi đổi loại thẻ vẫn lưu: trạng thái nửa vời mà
        // không ai biết. Nay: cần xếp lại mà đọc sổ lỗi thì
        // DỪNG TOÀN BỘ thay đổi và báo thật.
        var receipts: [Receipt] = []
        if reclassifyOld {
            do {
                receipts = try modelContext.fetch(FetchDescriptor<Receipt>())
            } catch {
                saveFailed = true
                return
            }
        }
        pending.card.brand = pending.brand
        pending.card.kind = pending.kind
        if reclassifyOld {
            let last4 = pending.last4
            // Lọc trong bộ nhớ thay cho #Predicate (tránh phụ thuộc macro với optional).
            for receipt in receipts where receipt.cardLast4 == last4 {
                receipt.classification = pending.kind
                receipt.classificationReason = "Xếp lại theo thẻ •• \(last4) — anh chọn đổi cả hoá đơn cũ"
            }
        }
        if !saveContextOrFalse(modelContext) {
            modelContext.rollback()
            saveFailed = true
        }
    }
}

// MARK: - Dữ liệu trung gian của form thẻ

struct CardFormData {
    var existingCard: CardTail? = nil
    var last4: String
    var brand: String
    var kind: Classification
}

struct PendingKindChange {
    var card: CardTail
    var brand: String
    var kind: Classification
    var last4: String
}

enum CardFormTarget: Identifiable {
    case new
    case edit(CardTail)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let card): return "edit-\(card.last4)-\(card.createdAt.timeIntervalSince1970)"
        }
    }
}

// MARK: - Form thêm / sửa thẻ

struct CardFormView: View {
    var target: CardFormTarget
    var existingTails: [CardTail]
    var onComplete: (CardFormData) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var last4Text: String
    @State private var brandText: String
    @State private var selectedKind: Classification
    @State private var errorText: String? = nil

    init(target: CardFormTarget, existingTails: [CardTail], onComplete: @escaping (CardFormData) -> Void) {
        self.target = target
        self.existingTails = existingTails
        self.onComplete = onComplete
        switch target {
        case .new:
            _last4Text = State(initialValue: "")
            _brandText = State(initialValue: "")
            _selectedKind = State(initialValue: .business)
        case .edit(let card):
            _last4Text = State(initialValue: card.last4)
            _brandText = State(initialValue: card.brand)
            _selectedKind = State(initialValue: card.kind == .unknown ? .personal : card.kind)
        }
    }

    private var isEditing: Bool {
        if case .edit = target { return true }
        return false
    }

    private var editedCard: CardTail? {
        if case .edit(let card) = target { return card }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("4 số cuối của thẻ") {
                    TextField("VD: 2586", text: $last4Text)
                        .keyboardType(.numberPad)
                        .monospacedDigit()
                        .disabled(isEditing) // đổi đuôi = thêm thẻ mới, không sửa đuôi của thẻ cũ
                    TextField("Hãng / nhãn (VD: Mastercard Debit)", text: $brandText)
                }
                Section("Thẻ này dùng cho") {
                    Picker("Loại", selection: $selectedKind) {
                        Text("CÁ NHÂN").tag(Classification.personal)
                        Text("BUSINESS").tag(Classification.business)
                    }
                    .pickerStyle(.segmented)
                    Text("Hoá đơn trả bằng thẻ này sẽ được GỢI Ý xếp vào loại trên — anh luôn đổi được từng tờ.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let errorText {
                    Section {
                        Text(errorText).foregroundStyle(.red).font(.callout)
                    }
                }
                Section {
                    Button("Lưu thẻ") { submit() }
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(isEditing ? "Sửa Thẻ" : "Thêm Thẻ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        let digits = last4Text.filter { $0.isNumber }
        guard digits.count == 4 else {
            errorText = "Anh nhập đúng 4 số cuối của thẻ giúp em."
            return
        }
        if !isEditing, existingTails.contains(where: { $0.last4 == digits && !$0.archived }) {
            errorText = "Đuôi \(digits) đã có trong danh sách thẻ đang dùng."
            return
        }
        let data = CardFormData(
            existingCard: editedCard,
            last4: digits,
            brand: brandText.trimmingCharacters(in: .whitespaces),
            kind: selectedKind
        )
        onComplete(data)
        dismiss()
    }
}
