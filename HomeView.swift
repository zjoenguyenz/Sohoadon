import SwiftUI
import SwiftData

/// Trang Chủ: thẻ Chờ Duyệt lên đầu (khi có việc), 2 ô tổng năm nay
/// Cá nhân / Business tách bạch, vài hoá đơn gần nhất. (DESIGN-V2 / Copilot Money)
struct HomeView: View {
    @Query(sort: \Receipt.date, order: .reverse) private var receipts: [Receipt]

    private var currentYearReceipts: [Receipt] {
        let year = Calendar.current.component(.year, from: Date())
        return receipts.filter { Calendar.current.component(.year, from: $0.date) == year }
    }

    private var needsReviewCount: Int {
        receipts.filter { $0.status == .needsReview }.count
    }

    private func yearSum(_ kind: Classification) -> Int {
        currentYearReceipts.filter { $0.classification == kind }.reduce(0) { $0 + ($1.totalCents ?? 0) }
    }

    private var topCategories: [(name: String, kind: Classification, total: Int)] {
        var totals: [String: (Classification, Int)] = [:]
        for receipt in currentYearReceipts {
            let key = receipt.category.isEmpty ? "Khác" : receipt.category
            let old = totals[key] ?? (receipt.classification, 0)
            totals[key] = (receipt.classification, old.1 + (receipt.totalCents ?? 0))
        }
        return totals
            .map { (name: $0.key, kind: $0.value.0, total: $0.value.1) }
            .sorted { $0.total > $1.total }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                if needsReviewCount > 0 {
                    Section {
                        NavigationLink {
                            ReceiptListView(onlyNeedsReview: true)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "tray.full.fill")
                                    .font(.title3)
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(needsReviewCount) hoá đơn chờ phân loại / duyệt")
                                        .font(.body.weight(.semibold))
                                    Text("Chưa duyệt = chưa phải chứng từ chính thức")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }

                Section("Năm nay — \(String(Calendar.current.component(.year, from: Date())))") {
                    HStack(spacing: 12) {
                        totalTile(kind: .personal, cents: yearSum(.personal))
                        totalTile(kind: .business, cents: yearSum(.business))
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    if yearSum(.unknown) != 0 {
                        Text("Chưa rõ: \(formatMoney(cents: yearSum(.unknown)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !topCategories.isEmpty {
                    Section("Theo mục") {
                        ForEach(topCategories, id: \.name) { entry in
                            HStack {
                                Image(systemName: entry.kind.iconName)
                                    .foregroundStyle(entry.kind.color)
                                Text(entry.name)
                                Spacer()
                                Text(formatMoney(cents: entry.total))
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                if !receipts.isEmpty {
                    Section("Gần đây") {
                        ForEach(receipts.prefix(5)) { receipt in
                            NavigationLink {
                                ReceiptDetailView(receipt: receipt)
                            } label: {
                                ReceiptRowView(receipt: receipt)
                            }
                        }
                    }
                } else {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.viewfinder")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Chưa có hoá đơn nào. Bấm nút CHỤP ở dưới để quét tờ đầu tiên.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }

                Section {
                    Text("Đọc ngay trên máy — ảnh hoá đơn không rời khỏi iPhone. Ảnh gốc lưu trong thư mục của app (Files → Trên iPhone → Sổ Hóa Đơn).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Sổ Hóa Đơn")
        }
    }

    private func totalTile(kind: Classification, cents: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: kind.iconName)
                Text(kind.label)
            }
            .font(.caption.bold())
            Text(formatMoney(cents: cents))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .foregroundStyle(kind.color)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Báo Cáo Thuế (Build 1: bảng tổng theo năm — xuất Tax Pack để bản sau)

struct ReportsView: View {
    @Query(sort: \Receipt.date, order: .reverse) private var receipts: [Receipt]
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private var availableYears: [Int] {
        var years = Set(receipts.map { Calendar.current.component(.year, from: $0.date) })
        years.insert(Calendar.current.component(.year, from: Date()))
        return years.sorted(by: >)
    }

    private var yearReceipts: [Receipt] {
        receipts.filter { Calendar.current.component(.year, from: $0.date) == selectedYear }
    }

    private func sum(_ kind: Classification, in items: [Receipt]) -> Int {
        items.filter { $0.classification == kind }.reduce(0) { $0 + ($1.totalCents ?? 0) }
    }

    private var categoryRows: [(name: String, kind: Classification, total: Int, count: Int)] {
        var grouped: [String: (Classification, Int, Int)] = [:]
        for receipt in yearReceipts where receipt.classification != .unknown {
            let key = "\(receipt.classificationRaw)|\(receipt.category.isEmpty ? "Khác" : receipt.category)"
            let old = grouped[key] ?? (receipt.classification, 0, 0)
            grouped[key] = (receipt.classification, old.1 + (receipt.totalCents ?? 0), old.2 + 1)
        }
        return grouped
            .map { (name: $0.key.components(separatedBy: "|").last ?? $0.key, kind: $0.value.0, total: $0.value.1, count: $0.value.2) }
            .sorted { a, b in
                if a.kind != b.kind { return a.kind == .business }
                return a.total > b.total
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Năm thuế", selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Tổng năm \(String(selectedYear))") {
                    HStack {
                        Label("CÁ NHÂN", systemImage: "person.fill")
                            .foregroundStyle(Theme.personalColor)
                        Spacer()
                        Text(formatMoney(cents: sum(.personal, in: yearReceipts)))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                    }
                    HStack {
                        Label("BUSINESS", systemImage: "briefcase.fill")
                            .foregroundStyle(Theme.businessColor)
                        Spacer()
                        Text(formatMoney(cents: sum(.business, in: yearReceipts)))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                    }
                    if sum(.unknown, in: yearReceipts) != 0 {
                        HStack {
                            Label("CHƯA RÕ", systemImage: "questionmark.circle.fill")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatMoney(cents: sum(.unknown, in: yearReceipts)))
                                .monospacedDigit()
                        }
                    }
                    Text("\(yearReceipts.count) hoá đơn · \(yearReceipts.filter { $0.status == .needsReview }.count) tờ đang chờ duyệt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !categoryRows.isEmpty {
                    Section("Theo mục (Schedule C worksheet — bản xem trước)") {
                        ForEach(categoryRows, id: \.name) { row in
                            HStack {
                                Image(systemName: row.kind.iconName)
                                    .foregroundStyle(row.kind.color)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(row.name)
                                    Text("\(row.count) hoá đơn")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formatMoney(cents: row.total))
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                Section {
                    Text("Xuất hồ sơ thuế (Tax Pack: PDF + CSV + ZIP theo năm) sẽ có ở bản sau. Bản này mới có bảng tổng xem trước.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Báo Cáo Thuế")
        }
    }
}
