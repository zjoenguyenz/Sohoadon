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

    // UI-2026-11-13: Trang Chủ dựng lại theo DesignSystem —
    // thẻ hero tổng năm + thanh chia tỉ lệ Cá nhân/Business,
    // banner chờ duyệt dạng thẻ cảnh báo, các khối là DSCard
    // trên ScrollView (chuẩn app tài chính top: số liệu lớn
    // lên đầu, một điểm nhấn màu, khoảng trắng đều thang 4).
    // MỌI phép tính dữ liệu giữ nguyên như bản List cũ.
    private var yearTotalCents: Int {
        yearSum(.personal) + yearSum(.business) + yearSum(.unknown)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.spaceL) {
                    if needsReviewCount > 0 {
                        NavigationLink {
                            ReceiptListView(onlyNeedsReview: true)
                        } label: {
                            HStack(spacing: DS.spaceM) {
                                Image(systemName: "tray.full.fill")
                                    .font(.title3)
                                    .foregroundStyle(DS.warning)
                                    .frame(width: 40, height: 40)
                                    .background(DS.warning.opacity(0.14))
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(needsReviewCount) hoá đơn chờ phân loại / duyệt")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("Chưa duyệt = chưa phải chứng từ chính thức")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(DS.spaceL)
                            .dsCard()
                        }
                        .buttonStyle(.plain)
                    }

                    heroCard

                    if !topCategories.isEmpty {
                        VStack(alignment: .leading, spacing: DS.spaceS) {
                            sectionTitle("Theo mục")
                            VStack(spacing: 0) {
                                ForEach(Array(topCategories.enumerated()), id: \.element.name) { index, entry in
                                    HStack(spacing: DS.spaceM) {
                                        Image(systemName: entry.kind.iconName)
                                            .font(.callout)
                                            .foregroundStyle(entry.kind.color)
                                            .frame(width: 32, height: 32)
                                            .background(entry.kind.color.opacity(0.13))
                                            .clipShape(Circle())
                                        Text(entry.name)
                                            .lineLimit(1)
                                        Spacer()
                                        MoneyAmount(cents: entry.total, font: .callout.weight(.semibold))
                                    }
                                    .padding(.vertical, DS.spaceS)
                                    if index < topCategories.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                            .padding(.horizontal, DS.spaceL)
                            .padding(.vertical, DS.spaceS)
                            .dsCard()
                        }
                    }

                    if !receipts.isEmpty {
                        VStack(alignment: .leading, spacing: DS.spaceS) {
                            sectionTitle("Gần đây")
                            VStack(spacing: 0) {
                                ForEach(Array(receipts.prefix(5).enumerated()), id: \.element.id) { index, receipt in
                                    NavigationLink {
                                        ReceiptDetailView(receipt: receipt)
                                    } label: {
                                        ReceiptRowView(receipt: receipt)
                                    }
                                    .buttonStyle(.plain)
                                    if index < min(5, receipts.count) - 1 {
                                        Divider()
                                    }
                                }
                            }
                            .padding(.horizontal, DS.spaceL)
                            .padding(.vertical, DS.spaceS)
                            .dsCard()
                        }
                    } else {
                        VStack(spacing: DS.spaceS) {
                            Image(systemName: "doc.viewfinder")
                                .font(.system(size: 40))
                                .foregroundStyle(DS.brand)
                            Text("Chưa có hoá đơn nào")
                                .font(.headline)
                            Text("Bấm nút CHỤP ở dưới để quét tờ đầu tiên.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DS.spaceXL)
                        .dsCard()
                    }

                    Text("Đọc ngay trên máy — ảnh hoá đơn không rời khỏi iPhone. Ảnh gốc lưu trong thư mục của app (Files → Trên iPhone → GL-Keeper).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(DS.spaceL)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("GL-Keeper")
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: DS.spaceM) {
            Text("NĂM NAY — \(String(Calendar.current.component(.year, from: Date())))")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Text(formatMoney(cents: yearTotalCents))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            splitBar
            HStack(spacing: DS.spaceL) {
                splitLegend(kind: .personal)
                splitLegend(kind: .business)
                if yearSum(.unknown) != 0 {
                    splitLegend(kind: .unknown)
                }
            }
        }
        .padding(DS.spaceL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }

    private var splitBar: some View {
        GeometryReader { geo in
            let total = max(yearTotalCents, 1)
            HStack(spacing: 2) {
                Rectangle()
                    .fill(Theme.personalColor)
                    .frame(width: geo.size.width * CGFloat(yearSum(.personal)) / CGFloat(total))
                Rectangle()
                    .fill(Theme.businessColor)
                    .frame(width: geo.size.width * CGFloat(yearSum(.business)) / CGFloat(total))
                if yearSum(.unknown) != 0 {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: geo.size.width * CGFloat(yearSum(.unknown)) / CGFloat(total))
                }
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }

    private func splitLegend(kind: Classification) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle()
                    .fill(kind.color)
                    .frame(width: 8, height: 8)
                Text(kind.label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Text(formatMoney(cents: yearSum(kind)))
                .font(.callout.weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
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
