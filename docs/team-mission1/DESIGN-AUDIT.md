# DESIGN AUDIT — Build 1 vs DESIGN-V2 (Mission 1, Design Specialist)

Date: 2026-11-08 · Auditor role: Design (TEAM.md) · Scope: AUDIT ONLY, no code changed.
Method: every claim below is read from the Build 1 source itself and cites
file + view/struct. Anything not provable from source is labelled UNVERIFIED.
Build 1 targets iOS 17 (BUILD1-NOTES.md, `project.yml`), so the absence of
iOS 26 Liquid Glass APIs is NOT counted as a fault anywhere below. What is
counted is: where a surface exists, is it a designed surface or a bare system
default? Glass placement for the later iOS 26 build is specified in §4.9.

## Verdict tally (54 checkpoints, listed in §2–§3)

- **COMPLIES: 20**
- **BARE-OR-MISSING: 34** — of which 11 are partial/bare executions of a
  present feature (◐) and 23 are missing or rule-breaking (✗).

The foundation is right (exact locked colours, badge component, running
total, suggestion-with-reason). The failures are concentrated where the user
touches the app daily: scanning blocks him, cards cannot be tapped, the two
most important money numbers are tinted on translucent backgrounds, and
money is edited in a 110 pt box.

---

## 1. Findings ordered by user-visible impact (highest first)

1. **Scanning blocks the user; there is no background processing and no Pile
   Mode.** `ScanView` (`build1/ScanView.swift`) sets `isProcessing = true`,
   shows a `ProgressView` on the Scan tab, and only presents `ReviewView`
   after OCR + parse finish. No receipt is saved with a "Đang đọc…" status,
   there is no queue, no progress count ("Đang đọc 3/12 tờ"), and only page 0
   of a multi-page scan is processed (`scan.imageOfPage(at: 0)`, comment in
   code admits this). This directly breaks the Expensify SmartScan rule in
   DESIGN-V2 ("Chụp xong là xong việc của người dùng… đọc chạy nền") and
   makes the backlog-of-receipts job — the user's real first workload — a
   wait-at-the-camera job. Severity: **Cao**.
2. **Cards are not Wallet cards and cannot be tapped.** `CardsView.cardRow`
   (`build1/CardsView.swift`) draws an 86×56 pt thumbnail inside a `List`
   row. It is not a physical-card surface (no 1.586 aspect, no stacking),
   and the row has no `NavigationLink`/tap action at all — the only
   interaction is an `ellipsis.circle` menu (Sửa / Ngưng). DESIGN-V2/Wallet
   requires: tap a card → all of that card's receipts + its year total.
   That destination screen does not exist in Build 1. The card is the
   anchor of the whole classification system and it is currently a dead
   picture. Severity: **Cao**.
3. **The two biggest money numbers break the amount rule.** DESIGN-V2:
   "số tiền luôn chữ chính, monospaced digit, nền đặc" (primary colour,
   monospaced, opaque surface). `HomeView.totalTile` (`build1/HomeView.swift`)
   renders the year totals with `.foregroundStyle(kind.color)` (tinted blue
   / orange text) on `kind.color.opacity(0.12)` (translucent). The running
   total in `ReceiptListView` (`build1/ReceiptViews.swift`) does the same
   with its per-kind sums (`.foregroundStyle(Theme.personalColor /
   businessColor)`). These are exactly the numbers a low-vision user must
   read at a glance, and they are the lowest-contrast text in the app.
   Severity: **Cao**.
4. **Money is edited in a small box; per-field confidence is invisible.**
   `ReviewView.moneyField` (`build1/ReceiptViews.swift`) is a `TextField`
   `.frame(width: 110)` in a list row — the exact pattern DESIGN-V2/Revolut
   forbids ("không sửa tiền trong ô nhỏ") in favour of a hero mono editor.
   Separately, only the total's confidence is shown (one caption line,
   `ReviewView` body); `vendorConfidence`/`dateConfidence` are stored
   (`Models.swift`, `Receipt`) but never surfaced, and no field is
   highlighted yellow for "Anh kiểm tra giúp chỗ này" as BLUEPRINT §5
   requires — warnings exist only as a generic orange list. A misread digit
   in a 110 pt right-aligned field is the most expensive error this app can
   ship. Severity: **Cao**.
5. **No onboarding, and the centre CHỤP tab is an ordinary tab.**
   `ContentView`/`TabShellView` (`build1/ContentView.swift`) go straight
   from the lock screen to a stock `TabView`; there is no first-run flow at
   all (the starter card •• 2586 is seeded silently in
   `TabShellView.seedStarterCardIfNeeded`). DESIGN-V2/Things 3 requires
   onboarding = do the real thing (1-sentence explanation → register a card
   → scan one receipt), and DESIGN-V2/Revolut requires the centre scan
   button to be visibly larger — the visual anchor of the app. In code the
   CHỤP `tabItem` is a standard `Label` with no size difference at all
   (BUILD1-NOTES risk #6 concedes this). Severity: **Cao** for a first-time
   user, Trung bình after.
6. **Primary buttons use the classification blue.** `ScanView` (Quét hoá
   đơn), `ReviewView` (Lưu hoá đơn) and the lock screen
   (`ContentView.lockScreen`) all use `.borderedProminent`, whose tint is
   the system blue — visually the Personal colour family. DESIGN-V2:
   "màu nút chính trung tính — xanh/cam chỉ mang nghĩa dữ liệu, không
   trang trí." A blue Save button teaches the user that blue sometimes
   means "Personal" and sometimes means "press here". Severity:
   **Trung bình–Cao**.
7. **Centrepiece dashboard pieces are bare list rows, not designed cards.**
   The To Review entry (`HomeView`) is correctly FIRST (§3.1) but is a
   plain `List` row — no card surface, no inline per-receipt review /
   swipe actions per DESIGN-V2/Copilot. "Theo mục" (`HomeView`) is plain
   text rows — no Swift Charts bars, despite DESIGN-V2 making the category
   chart and the "Năm thuế nhìn lại" page signature surfaces. Severity:
   **Trung bình**.
8. **Month headers show two unlabelled numbers.** `ReceiptListView`
   section header renders `"\(personal) · \(business)"` with no icon, no
   label, no colour — the user must memorise the order. This is the
   inverse failure of "never colour alone": here there is NO signal at
   all. Severity: **Trung bình**.
9. **Filter UI carries no classification identity.** `ReceiptListView`
   filtering is a toolbar `Menu` whose items are plain text ("Cá nhân",
   "Business", "Chưa rõ") — no icon, no colour. DESIGN-V2/Copilot: "Một
   mục = một màu duy nhất ở mọi nơi: card, chip lọc, biểu đồ…" — there are
   no filter chips. Severity: **Trung bình**.
10. **Receipt detail violates one-screen-one-job.** `ReceiptDetailView`
    (`build1/ReceiptViews.swift`) shows ALL fields at once (vendor, date,
    subtotal, tax, total, card, plus the developer-facing "Mã chống trùng"
    dedupe key), exposes Xoá and Duyệt as full list buttons instead of
    gathering secondary actions into a ••• menu, and gives TỔNG no hero
    treatment (same size as subtotal, only bold). DESIGN-V2/Wallet +
    Things 3 require: big evidence photo on top, 5 main fields by default,
    the rest behind progressive disclosure, secondary actions in •••.
    Severity: **Trung bình**.
11. **Duplicate handling is a text alert, not a comparison.**
    `ReviewView` shows `.alert("Có vẻ hoá đơn này đã có trong sổ")` with
    "Vẫn lưu thêm / Huỷ". DESIGN-V2/Expensify requires the two images side
    by side with Giữ cả hai / Chỉ giữ bản mới / Chỉ giữ bản cũ. With
    thermal receipts re-scanned before they fade, side-by-side is how the
    user actually decides. Severity: **Trung bình**.
12. **No signature save moment; no haptics; no designed success state.**
    No file in Build 1 contains any animation or haptic call (verified by
    reading all six UI files: no `withAnimation`, no `matchedGeometryEffect`,
    no `sensoryFeedback`). `ReviewView.save` simply dismisses the sheet.
    DESIGN-V2/Things 3 specifies exactly one signature micro-animation
    (thumbnail flies into the correct-colour compartment + light haptic
    "đã cất vào sổ"). Its absence is why the app will feel like a form, not
    a sổ. Severity: **Trung bình**.
13. **Touch targets below 44 pt in several controls.** Segmented pickers
    (`ReviewView`, `ReceiptDetailView`, `CardFormView`, `ReportsView` —
    system segmented height ≈32 pt, UNVERIFIED on device, standard UIKit
    metrics), the `ellipsis.circle` menu button in `CardsView.cardRow`
    (icon-only, `.font(.title3)`, no 44 pt frame), and the
    `ClassificationBadge`'s own height (~20 pt — display-only, so not a
    target violation, noted for completeness). DESIGN-V2 and TEAM.md both
    lock ≥44 pt. Severity: **Trung bình** (daily-use pickers).
14. **Dynamic Type is only half-safe.** All text uses semantic styles
    (`.body`, `.callout`, `.caption`, `.title3`) — good. But
    `HomeView.totalTile` forces `.lineLimit(1)` + `.minimumScaleFactor(0.7)`
    on the year totals (amounts shrink instead of wrapping at large sizes),
    `ReviewView.moneyField` is fixed at 110 pt wide, `CardsView.cardRow`'s
    card thumbnail is a fixed 86×56 with `.caption` text inside, and no view
    uses `@ScaledMetric` or a vertical-stack fallback. AX5 behaviour is
    UNVERIFIED on device; the code patterns predict clipping/shrinking on
    the exact surfaces that carry money. Severity: **Trung bình**.
15. **Several empty/error states are missing entirely.** `ReportsView` has
    no empty state (a year with no receipts shows $0.00 rows and silence);
    `CardsView` has no empty state if all cards are archived; a missing
    receipt image silently removes the detail section (`ReceiptDetailView`)
    with no explanation; scan errors are a single red text line
    (`ScanView.errorText`) with no designed card and no explicit retry
    button. Where states DO exist they are bare `VStack` + secondary text
    (§3). Severity: **Trung bình**.
16. **Face ID lock screen is a stock placeholder.** `ContentView.lockScreen`:
    a grey `lock.fill` glyph, one bold line, a `.borderedProminent` button.
    Fail-open behaviour is correct (§3.8), but there is no app identity, no
    `faceid` glyph, no privacy line ("Đọc ngay trên máy — ảnh hoá đơn không
    rời khỏi iPhone") even though DESIGN-V2/Scanner Pro asks for that trust
    copy at the lock. This is the first screen the user sees every day.
    Severity: **Thấp–Trung bình**.
17. **The scanner has no guidance states.** `ScanView` presents Apple's
    stock `VNDocumentCameraViewController` with no overlay copy
    ("Đưa hoá đơn vào khung" → "Giữ yên…" → "Đã chụp ✓") and the pre-scan
    screen is a bare icon + paragraph + two stock buttons. The system's own
    Retake/Use step inside VisionKit does exist for the user (UNVERIFIED
    from Build 1 code — it is VisionKit-internal behaviour, not code in
    this repo). Severity: **Thấp–Trung bình**.
18. **Spacing is close to, but not on, the 4/8 grid, and only colours are
    tokenised.** `Models.swift` `Theme` defines exactly two colours and
    nothing else — no spacing, radius or typography tokens. Code uses
    spacings of 2, 3, 5, 6, 14 alongside 4/8/12/16/24 (e.g. `HomeView`
    `HStack(spacing: 5)`, `ReceiptRowView` `spacing: 3`,
    `ReceiptListView` running total `spacing: 14`). DESIGN-V2 polish
    checklist requires a uniform 4/8 pt grid. Severity: **Thấp**.

---

## 2. Foundation audit (DESIGN-V2 locked constraints)

| # | Constraint (DESIGN-V2) | Verdict | Evidence |
|---|---|---|---|
| 1 | Personal = #005EB8 exactly | ✓ COMPLIES | `Models.swift`, `Theme.personalColor = Color(red: 0, green: 94/255, blue: 184/255)` = 00/5E/B8 |
| 2 | Business = #9A4A00 exactly | ✓ COMPLIES | `Models.swift`, `Theme.businessColor = Color(red: 154/255, green: 74/255, blue: 0)` = 9A/4A/00 |
| 3 | Personal icon `person` + text "CÁ NHÂN"; Business icon `briefcase` + "BUSINESS" | ✓ COMPLIES | `Models.swift`, `Classification.iconName` (`person.fill` / `briefcase.fill`) and `Classification.label` (`CÁ NHÂN` / `BUSINESS`) |
| 4 | Classification ALWAYS shown with 4 signals: colour + icon + text + card-tail badge | ◐ PARTIAL | `ReceiptViews.swift`, `ClassificationBadge` renders icon + label + `•• last4` in kind colour — all 4 signals **only when `cardLast4` is non-empty**. When the tail is nil/empty (cash, unread card) the 4th signal silently disappears instead of being replaced by an explicit "Không thẻ / Tiền mặt" tail slot. Everywhere else classification appears as fewer signals: segmented picker text-only (`ReviewView`, `ReceiptDetailView`), filter menu text-only (`ReceiptListView` toolbar), month header no signal at all |
| 5 | Amounts in primary colour | ✗ FAILS in key places | Complies in `ReceiptRowView`, `ReceiptDetailView.moneyText`, `ReportsView` amount texts (no tint → `.primary`). Fails in `HomeView.totalTile` (kind-colour text) and `ReceiptListView` running-total per-kind sums (kind-colour text) |
| 6 | Amounts monospaced digits | ✓ COMPLIES | `.monospacedDigit()` present on amounts in `HomeView` (tiles, category rows), `ReceiptRowView`, `ReceiptListView` (running total, month header), `ReceiptDetailView.moneyText`, `ReviewView` (rows + `moneyField`), `ReportsView`, `CardsView.cardRow` (tail) |
| 7 | Amounts on opaque surfaces | ✗ FAILS in key places | `HomeView.totalTile` background is `kind.color.opacity(0.12)`; `ClassificationBadge` background is `kind.color.opacity(0.15)`. Badge tint is acceptable for a chip, but the year-total tiles put the app's biggest amounts on a translucent wash. List-row amounts sit on the opaque system list surface ✓ |
| 8 | Touch targets ≥ 44 pt | ✗ FAILS | See finding 13. Complying: `ScanView` large buttons (`.controlSize(.large)` + full width), lock button (`ContentView`), `ReviewView` save button. Failing: segmented pickers in 4 views, `CardsView` ellipsis menu button (no minimum frame) |
| 9 | Dynamic Type friendliness (to AX5) | ◐ PARTIAL | Semantic fonts everywhere ✓; fixed-width/shrink patterns in `totalTile`, `moneyField`, `cardRow` thumbnail ✗ (finding 14). AX5 rendering UNVERIFIED on device |
| 10 | One colour per classification everywhere (card, filter chip, chart, PDF) | ✗ FAILS | Colour is consistent where it appears (`Classification.color` is the single source ✓), but there are no filter chips and no chart at all, and the PDF/Tax Pack does not exist in Build 1 — so "everywhere" currently means "in badges and tiles only" |
| 11 | Primary action button neutral; blue/orange = data only | ✗ FAILS | `.borderedProminent` (system blue) on `ScanView` scan button, `ReviewView` save button, `ContentView` unlock button |
| 12 | 4/8 pt spacing grid + uniform animation durations | ◐ PARTIAL | Mostly 4/8/12/16/24 with off-grid 2/3/5/6/14 exceptions (finding 18); there are no animations at all, so "uniform duration" is vacuous |
| 13 | Every loading/empty/error/success state designed | ◐ PARTIAL | Some states exist (see per-screen §3); Reports/Cards empties missing; errors are red text; success has no designed state |

---

## 3. Screen-by-screen audit

### 3.1 Home / Dashboard — `HomeView` in `build1/HomeView.swift`

**Complies**
- To Review is the FIRST section when `needsReviewCount > 0`, linking to
  `ReceiptListView(onlyNeedsReview: true)` — `HomeView` body, first
  `Section`. Matches DESIGN-V2/Copilot ("thẻ đầu tiên trên dashboard").
  Copy is honest: "N hoá đơn chờ phân loại / duyệt" + "Chưa duyệt = chưa
  phải chứng từ chính thức".
- Year totals are separated Personal / Business in two tiles with
  icon + label + colour (`totalTile(kind:cents:)`), unknown shown as a
  separate "Chưa rõ" line rather than silently merged.
- Recent receipts (5) reuse `ReceiptRowView` and navigate to detail ✓.
- Privacy trust copy is present at the bottom: "Đọc ngay trên máy — ảnh
  hoá đơn không rời khỏi iPhone…" ✓ (DESIGN-V2/Scanner Pro).
- An empty state exists: `doc.viewfinder` icon + "Chưa có hoá đơn nào.
  Bấm nút CHỤP ở dưới để quét tờ đầu tiên."

**Bare / default / missing**
- ◐ To Review is a plain list row, not a card; there is no inline review
  inside it (no per-receipt approve / swipe-as-mailbox per Copilot).
  Severity: Trung bình.
- ✗ Year-total amounts: kind-colour text on 12 % translucent background
  (finding 3); `.lineLimit(1)` + `.minimumScaleFactor(0.7)` shrink the
  number at large Dynamic Type (finding 14). Severity: Cao.
- ✗ "Theo mục" is six text rows. No Swift Charts bar chart, no visual
  proportion; and in `topCategories` the grouping key is the category name
  alone, so a category used by both kinds displays with whichever kind was
  seen first (`totals[key] ?? (receipt.classification, 0)`) — the row's
  single icon/colour can therefore mislabel mixed money. (Contrast
  `ReportsView.categoryRows`, which correctly keys by kind+category.)
  Severity: Trung bình.
- ✗ Dashboard modules are not pinnable/reorderable and there is no
  dashboard customisation (DESIGN-V2/Revolut). Severity: Thấp for V1 use.
- ◐ Empty state is a bare icon + 2 lines inside a list section — no call-
  to-action button (the user is told to use the tab bar, which §3.7 shows
  is unmarked). Severity: Thấp.

### 3.2 Receipt list — `ReceiptListView` + `ReceiptRowView` in `build1/ReceiptViews.swift`

**Complies**
- Running total of the exact filtered/searched set is the first section:
  count + Personal sum + Business sum (+ "Chưa rõ" when non-zero),
  monospaced — `ReceiptListView` body, first `Section`. It recomputes from
  `filtered`, so search and kind filter both update it ✓ (DESIGN-V2:
  "mọi kết quả lọc/tìm kiếm hiện tổng tiền của đúng tập đó ở trên cùng").
- Grouped by month, newest first (`monthGroups`) ✓ (DESIGN-V2/Wallet).
- Search is genuinely full-text: vendor, category, line-item names AND
  `ocrRawText` (`filtered`) ✓.
- Row anatomy (`ReceiptRowView`): 44×56 thumbnail, vendor `.body.weight
  (.semibold)`, date caption, `ClassificationBadge`, primary-colour
  monospaced amount ✓. "Chờ duyệt" status text present.
- Inbox-cleared empty copy is exactly the DESIGN-V2/Things 3 reward line:
  "Đã phân loại xong hết ✓" (when `onlyNeedsReview`). Search-no-match copy:
  "Chưa có hoá đơn nào khớp".

**Bare / default / missing**
- ✗ Month header subtotals are two bare numbers joined by " · " — no
  icon/label/colour signal (finding 8). Severity: Trung bình.
- ✗ Kind filter is a text-only toolbar `Menu`, not colour/icon chips
  (finding 9). The active filter is also not visibly indicated anywhere
  in the list UI (the menu label always reads "Lọc"). Severity: Trung bình.
- ◐ "Chờ duyệt" in the row is orange text only — no icon, no chip
  background; orange here is the system orange, not a defined status
  token, and it sits next to the Business badge whose colour family it
  resembles. Severity: Thấp–Trung bình.
- ◐ Running-total card is a plain list section (no designed summary
  surface); its per-kind amounts are tinted (finding 3). Severity:
  Trung bình.
- ◐ Empty overlay is a bare centred `VStack` over an otherwise blank
  list; no action offered (e.g. "Quét tờ đầu tiên" button in the
  no-receipts-at-all case). Severity: Thấp.
- Note (behaviour, flagged by BUILD1-NOTES #5, not scored): Home pushes
  this view inside its own `NavigationStack`, nesting stacks — title-bar
  behaviour may look off. UNVERIFIED on device.

### 3.3 Receipt detail — `ReceiptDetailView` in `build1/ReceiptViews.swift`

**Complies**
- Evidence image is the first section, `.scaledToFit`, capped 320 pt,
  full width — image-first per DESIGN-V2/Wallet (partially; see below).
- Classification section shows the badge AND the stored
  `classificationReason` AND an override picker — reason + override ✓.
- Flags are computed and shown in plain language (`receiptFlags`):
  item-sum ≠ subtotal, subtotal+tax ≠ total, missing total, Business
  without purpose ("Thiếu mục đích business — sở thuế hay soi điểm này"),
  unclassified ✓. Amount texts are primary + monospaced ✓.
- Line items listed with qty/tax flag and monospaced amounts ✓.
- Approve action wording is explicit: "Duyệt — đã kiểm, cho vào sổ chính
  thức"; delete is behind a `confirmationDialog` ✓.

**Bare / default / missing**
- ✗ No progressive disclosure: all fields incl. "Mã chống trùng"
  (dedupe key — internal jargon) are shown by default; DESIGN-V2 allows
  5 main fields by default (vendor, date, total, classification,
  category) with line items/tax/notes expanded on demand. Severity:
  Trung bình.
- ✗ Secondary actions are not in a ••• menu: Duyệt and Xoá are stacked
  list buttons at the bottom (Wallet rule: "hành động phụ gom vào nút
  •••"). Severity: Trung bình.
- ✗ TỔNG gets no hero treatment — same font size as Subtotal, only
  `.bold()`. Severity: Trung bình.
- ✗ Image has no tap-to-zoom (no gesture/sheet in code) although
  BLUEPRINT §5 requires the original to be zoomable as evidence; if the
  image file is missing the whole section silently vanishes. Severity:
  Trung bình.
- ◐ Classification override is a 3-segment control including "CHƯA RÕ"
  at ≈32 pt height (finding 13) and plain text — no colour/icon in the
  control itself. Severity: Trung bình.
- ◐ "Đã lưu ✓" success feedback is a `.caption` green text line
  (`savedNote`) — no haptic, no designed confirmation. Severity: Thấp.

### 3.4 Review after scan — `ReviewView` in `build1/ReceiptViews.swift`

**Complies**
- Suggestion always shows its REASON plus an override, adjacent, in one
  section headed "Phân loại — gợi ý theo thẻ, anh đổi được": `reasonText`
  (from `suggestClassification` in `Models.swift`, e.g. "Thẻ •• 2586 —
  đã đăng ký BUSINESS", "Không đọc được đuôi thẻ… — anh chọn giúp",
  "Thẻ …•• 2586 chưa đăng ký — anh chọn giúp") with the segmented picker
  directly underneath ✓ — this is the DESIGN-V2/Copilot pattern in
  substance.
- Warnings from the parser get their own first-class section, "Anh kiểm
  tra giúp", with warning icons ✓.
- Read card is shown back to the user ("Thẻ đọc được: Mastercard Debit
  •• 2586" / "Không thấy dòng thẻ") ✓.
- Line items are listed read-only with amounts ✓. Duplicate check runs
  before save (`checkDuplicate` / `attemptSave`) ✓ in substance.
- Save discipline (warnings / unknown / Business-without-purpose →
  `needsReview`) is enforced in `save` ✓ — the Hộp Chờ rule from
  FEATURES.md made it into code.

**Bare / default / missing**
- ✗ Money fields are 110 pt-wide `TextField`s (`moneyField`) — finding 4.
  No hero editor, no auto-shrink large mono number. Severity: Cao.
- ✗ Per-field confidence highlighting missing: only total confidence is
  printed as a caption percentage; a low-confidence vendor/date/total is
  not highlighted in place, and low-confidence core fields cannot be
  fixed inline in the Hộp Chờ later (DESIGN-V2/Expensify: fix in the To
  Review card, not only in detail). Severity: Cao.
- ✗ Duplicate dialog is a text `.alert` — no side-by-side images, no
  "Giữ cả hai" option (only "Vẫn lưu thêm" / "Huỷ"). Severity:
  Trung bình (finding 11).
- ✗ The reason is rendered as plain `.callout` secondary text — not the
  designed suggestion chip of DESIGN-V2 ("Thẻ •• 2586 — đã đăng ký
  Business [Đổi]") with the override as an explicit adjacent button; the
  segmented control below is easy to miss as "the override for this
  suggestion". Severity: Trung bình.
- ✗ Primary save button is `.borderedProminent` blue (finding 6).
  Severity: Trung bình.
- ◐ Evidence image capped at 220 pt here vs 320 pt in detail — visually
  inconsistent between the two screens that show the same photo.
  Severity: Thấp.

### 3.5 Scan — `ScanView` in `build1/ScanView.swift`

**Complies**
- Uses system VisionKit document camera (`DocumentCameraView` wrapping
  `VNDocumentCameraViewController`) per DESIGN-V2/Scanner Pro, with a
  PhotosPicker fallback and an explicit unsupported-camera message ✓.
- Privacy trust line present verbatim at the bottom: "Đọc ngay trên máy
  — ảnh hoá đơn không rời khỏi iPhone." ✓
- Every failure path produces a Vietnamese message (no page scanned, OCR
  empty, image-save failure, photo-load failure, camera error) — errors
  are never silent ✓ in substance.
- OCR runs off the main queue (`DispatchQueue.global`) and the original
  image is saved before processing (`ImageStore.saveJPEG`) — the
  original is never overwritten by an enhanced copy ✓.

**Bare / default / missing**
- ✗ **Blocking, synchronous-feeling flow** (finding 1): `process(image:)`
  → spinner on the tab → sheet. No background queue, no "Đang đọc…"
  receipt in the list, no completion notice "Đã đọc xong N tờ", no Pile
  Mode, multi-page scans truncated to page 0. Severity: Cao.
- ✗ Loading state is a bare `ProgressView()` (indefinite spinner) + one
  generic line "Đang đọc hoá đơn…" — DESIGN-V2 forbids the indefinite
  spinner without a counted status ("Đang đọc 3/12 tờ"). Severity:
  Trung bình (subsumed by finding 1 for a single receipt).
- ✗ No guidance overlay states around capture (finding 17); pre-scan
  screen is stock icon + paragraph + two stock buttons, no designed
  surface. Severity: Trung bình.
- ✗ Error presentation is one red `.callout` text block — no error card,
  no "Chụp lại" retry button attached to the error, no distinction
  between recoverable (blurry photo) and storage errors. Severity:
  Trung bình.
- ✗ Scan primary button is `.borderedProminent` blue (finding 6).

### 3.6 Cards & Settings — `CardsView`, `CardFormView` in `build1/CardsView.swift`

**Complies**
- Card-management rules are fully implemented and match BLUEPRINT §5:
  add / edit / archive-never-delete, and changing a card's kind raises a
  `confirmationDialog` asking "Chỉ áp dụng từ nay" vs "Xếp lại cả hoá
  đơn cũ của thẻ này" ✓ — a model of the reason+choice pattern.
- The card thumbnail uses the classification colour as its fill with the
  kind icon and `•• last4` in white — the right instinct (colour by kind,
  brand + tail) ✓ in miniature.
- Footer copy sets expectations correctly: "App chỉ nhớ 4 số cuối + hãng
  thẻ… Đuôi thẻ là GỢI Ý phân loại, anh luôn đổi được từng hoá đơn." ✓
- `CardFormView` validates (exactly 4 digits, duplicate active tail) with
  plain Vietnamese errors, locks the tail field when editing, and states
  the suggestion rule under the kind picker ✓.
- Settings section exposes the Face ID toggle with an honest fail-open
  explanation, plus storage/OCR-privacy `LabeledContent` rows ✓.

**Bare / default / missing**
- ✗ Not a physical card and not tappable (finding 2): 86×56 thumbnail in
  a list row; no stack, no full-width card, no navigation to the card's
  receipts, no per-card count or year total anywhere. Severity: Cao.
- ✗ No empty state: archive every card and the tab shows only the add
  button with no explanation. Severity: Thấp–Trung bình.
- ✗ The only card actions hide behind an `ellipsis.circle` icon button
  with no 44 pt frame (finding 13). Severity: Trung bình.
- ◐ Settings are bare `Form`/`List` defaults — acceptable for settings,
  but there is no designed grouping (no card surfaces, no app-info /
  backup section despite the Tax Pack depending on the Files folder).
  Severity: Thấp.
- ◐ Archived cards render at `opacity(0.6)` — greyed by transparency
  over the list background rather than a designed archived treatment;
  their kind label remains tinted at reduced contrast. Severity: Thấp.

### 3.7 Tab shell — `TabShellView` in `build1/ContentView.swift`

**Complies**
- Exactly the 5 BLUEPRINT tabs, in order, with Vietnamese labels and
  system icons: Trang Chủ · Hoá Đơn · CHỤP · Báo Cáo Thuế · Thẻ & Cài
  Đặt ✓.

**Bare / default / missing**
- ✗ Centre CHỤP is a standard tab item — no enlarged/raised centre
  button, no visual anchor (finding 5; BUILD1-NOTES #6 concedes).
  Severity: Trung bình–Cao (it is the app's main verb).
- ✗ No badge on the Hoá Đơn / Trang Chủ tab showing the To Review count
  — the user must open Home to learn work is waiting. Severity:
  Trung bình.
- ✗ Stock `TabView` styling throughout: no designed tab-bar treatment
  of any kind on iOS 17 (this is the surface where Liquid Glass belongs
  in the iOS 26 build — §4.9). Severity: Thấp on iOS 17, by design.

### 3.8 Face ID lock — `ContentView` in `build1/ContentView.swift`

**Complies**
- Fail-open is real and matches TEAM.md's no-repeat catalogue: no
  biometrics/passcode → app opens with an explanatory `lockNote`; auth
  failure → note + retry button; re-locks on `.background`, retries on
  `.active` ✓. Uses `.deviceOwnerAuthentication` (Face ID with passcode
  fallback) ✓.
- Unlock button is `.controlSize(.large)` — touch target ✓.

**Bare / default / missing**
- ◐ Lock screen design is a stock placeholder (finding 16): grey
  `lock.fill` at 44 pt, `.title3.bold` line, one prominent button, bare
  `.padding()`. No app mark, no `faceid` glyph, no privacy line, no
  designed background surface. Severity: Thấp–Trung bình.
- ◐ The failure note ("Chưa mở được — anh bấm nút dưới để thử lại…") is
  the same `.callout` secondary style as the fail-open note — error and
  information states are visually indistinguishable. Severity: Thấp.

### 3.9 Reports / Tax — `ReportsView` in `build1/HomeView.swift`

**Complies**
- Year picker + per-kind totals with icon + label + colour on the labels
  and primary monospaced amounts ✓; category breakdown keyed correctly
  by kind+category with counts ✓; an honest footnote states the Tax Pack
  is not in this build ✓ (no fake export buttons).

**Bare / default / missing**
- ✗ No "Năm thuế nhìn lại" hero page and no chart (DESIGN-V2/Copilot
  makes this the cover of the tax PDF). Severity: Trung bình.
- ✗ No Tax Pack export (PDF/CSV/ZIP) and therefore no pre-export warning
  for unclassified receipts (BLUEPRINT §5 requires the warning). Admitted
  deferral in BUILD1-NOTES — recorded here as missing, not as a surprise.
  Severity: Trung bình.
- ✗ No empty state for a receipt-less year (finding 15). The year picker
  is `.segmented`, which will crowd as years accumulate and is ≈32 pt
  tall (finding 13). Severity: Thấp–Trung bình.
- ◐ Needs-review count is a `.caption` line inside the totals section —
  the tax-readiness signal ("N tờ đang chờ duyệt") deserves a designed
  warning row, since exporting with pending receipts is the failure this
  screen exists to prevent. Severity: Trung bình.

### 3.10 Onboarding — absent

- ✗ **There is no onboarding anywhere in Build 1** — no first-run view,
  no card-registration walkthrough, no practice scan; the starter card is
  seeded silently (`ContentView.swift`, `seedStarterCardIfNeeded`).
  Stated plainly per the brief: absent, legitimately out of Build 1's
  foundation scope, and fully specified for Build 2 in §4.10.
  Severity: Trung bình (first-run only, but it is where the card-tail
  concept — the app's core idea — must be taught).

---

## 4. Build 2 design spec (implementable as written — no invention needed)

Conventions for this section: all fonts are semantic Dynamic Type styles
unless a system size is given; "amount" always means `formatMoney` output
rendered `.monospacedDigit()`; every interactive element has a minimum
44×44 pt hit area (use `.frame(minWidth: 44, minHeight: 44)` +
`.contentShape(Rectangle())` where the glyph is smaller); spacing only
from {4, 8, 12, 16, 24, 32}.

### 4.0 Global tokens (add to `Theme` in `Models.swift`)

Colours (hex, exact):

| Token | Light | Dark | Use |
|---|---|---|---|
| `personal` | #005EB8 | #005EB8 | data only: Personal icon/text/chart marks |
| `business` | #9A4A00 | #C97A2E | data only: Business icon/text/chart marks (dark value lightened for contrast on black — UNVERIFIED against a contrast checker; verify ≥4.5:1 before shipping) |
| `unknown` | #6E6E73 | #98989F | "CHƯA RÕ" icon/text |
| `personalTint` (opaque) | #D9E7F4 | #162A3E | badge/tile backgrounds — replaces `opacity(0.15)` |
| `businessTint` (opaque) | #F0E4D9 | #382616 | badge/tile backgrounds — replaces `opacity(0.15)` |
| `unknownTint` (opaque) | #ECECF0 | #2C2C2E | badge background |
| `amountInk` | `.primary` | `.primary` | ALL amount text, no exceptions |
| `warningFg` / `warningBg` | #7A5200 / #FCEFD2 | #FFD60A / #3A3000 | flags, To Review accents |
| `errorFg` / `errorBg` | #A4262C / #FDF0EF | #FF9D97 / #3D1512 | error cards |
| `successFg` / `successBg` | #1F7A33 / #E4F2E7 | #4CC38A / #12291B | saved/reviewed confirmations |
| `primaryButtonBg` / `Fg` | #1C1C1E / #FFFFFF | #F2F2F7 / #1C1C1E | the ONE primary button per screen (neutral — never blue/orange) |

Surfaces: content always on opaque `Color(uiColor: .systemBackground)` or
`.secondarySystemBackground`. No `opacity()` colour washes under amounts
anywhere. Chart marks may use `personal`/`business` (data colour), chart
value labels stay `amountInk`.

Typography scale:
- Screen title: navigation title, `.large` display mode on tab roots.
- Amount hero (detail total, hero editor): `.largeTitle` `.bold`,
  monospaced digits, `minimumScaleFactor(0.5)`, `lineLimit(1)`.
- Amount primary (tiles, running total): `.title2` `.semibold`, mono.
- Amount row (lists): `.body` `.semibold`, mono.
- Card/section headings: `.headline`. Body: `.body`. Secondary: `.callout`
  `.secondary`. Captions/badges: `.caption` `.bold`.
- At accessibility sizes (≥ AX1, detect via `dynamicTypeSize.isAccessibilitySize`):
  the two Home year tiles stack vertically instead of side-by-side, and
  every `HStack` of label+amount in §4.3/§4.8 wraps amount under the label.
  No `minimumScaleFactor` below 0.5 on amounts; never shrink below
  `.callout` effective size — wrap instead.

### 4.1 Badge anatomy (`ClassificationBadge` — rebuild)

- Height 28 pt; horizontal padding 10; spacing 4; corner radius 14 (capsule).
- Contents, left→right: kind icon (SF Symbol, 12 pt), kind label
  (`.caption` `.bold`, tracking 0.3), tail segment — ALWAYS present:
  `•• 2586` (`.caption` `.bold`, monospaced) when a tail exists, otherwise
  the literal text `KHÔNG THẺ` so the 4th signal slot never disappears.
- Foreground: kind colour (`personal`/`business`/`unknown` token).
  Background: the matching **opaque** tint token. No opacity modifiers.
- The badge is display-only (not a button); where it is tappable (filter
  chips, §4.3) use the chip spec instead.
- Status chip (separate component, `StatusChip`): "Chờ duyệt" =
  `tray.full.fill` icon 11 pt + text `.caption` `.bold`, `warningFg` on
  `warningBg`, same 28 pt capsule anatomy. "Đã duyệt" is NOT shown in
  rows (absence = reviewed); it appears only in detail.

### 4.2 Classification picker (replaces every segmented "Loại" control)

Two (three in Review/Detail where unknown is legal) large option cards in
a row, each: min height 64 pt, corner radius 12, opaque tint background,
2 pt border in kind colour when selected (clear when not), contents =
icon 20 pt + label `.body` `.bold` + (in Review only) the card tail
`•• 2586` `.caption` monospaced underneath. Labels: `CÁ NHÂN` /
`BUSINESS` / `CHƯA RÕ`. Selection fires `.selection` haptic. This one
component is used in `ReviewView`, `ReceiptDetailView`, `CardFormView` —
no segmented pickers remain for classification anywhere.

### 4.3 Tab bar (`TabShellView` — custom bar, iOS 17)

- Custom bottom bar: height 64 pt + safe-area inset, opaque
  `.systemBackground` with a 0.5 pt top separator. Five equal slots.
- Centre slot is the anchor: circular button, diameter 56 pt, centre
  raised 18 pt above the bar's top edge, fill `primaryButtonBg`, glyph
  `camera.fill` 24 pt in `primaryButtonFg`, label "CHỤP" `.caption2`
  `.bold` under the circle inside the bar. Tapping it selects the Scan
  tab. Hit area 64×64.
- Other tabs: icon 22 pt + label `.caption2`; selected = `.primary`,
  unselected = `.secondary`. (Tab tint is neutral; blue/orange never
  appear in the bar.)
- To Review badge: on the Trang Chủ tab icon, top-trailing — circle
  18 pt, `errorFg`-red family fill #C81E1E, white `.caption2` `.bold`
  count, hidden when 0. VoiceOver label: "Trang Chủ, N hoá đơn chờ duyệt".
- iOS 26 build: this same bar is where Liquid Glass goes (§4.9). The
  custom layout above is the fallback for iOS 17.

### 4.4 Home (`HomeView`)

Layout: `ScrollView` of cards, horizontal margin 16, vertical spacing 16,
card = opaque `.systemBackground` on `.secondarySystemBackground` page
background, corner radius 16, padding 16, subtle shadow
(`black.opacity(0.06)`, radius 8, y 2).

1. **To Review card** (only when count > 0), first, always:
   - Top row =
     `tray.full.fill` 20 pt `warningFg` + "Hộp Chờ Duyệt" `.headline` +
     spacer + count pill (count, `.callout` `.bold`, white on #C81E1E,
     capsule, min 28×28).
   - Subline `.callout` `.secondary`: "Chưa duyệt = chưa phải chứng từ
     chính thức".
   - Up to 3 pending receipts inline, each a mini-row (thumbnail 36×44,
     vendor `.body` semibold 1 line, amount `.body` semibold mono
     `amountInk`, badge §4.1) with two inline actions on swipe-trailing:
     "Duyệt" (`successBg`/`successFg`) and "Mở" (neutral). Full-card tap
     and a bottom button "Duyệt tất cả tờ đã rõ" (height 44, neutral
     secondary style) go to `ReceiptListView(onlyNeedsReview: true)`.
   - If count > 3: footer line "+ thêm N tờ nữa" `.caption` `.secondary`.
2. **Year totals card** "Năm nay — {year}": two tiles side by side
   (stacked at AX sizes, §4.0), spacing 12. Tile anatomy: radius 12,
   opaque tint background (`personalTint`/`businessTint`), padding 12;
   top row icon 16 pt + label `.caption` `.bold` in kind colour; amount
   below in `.title2` `.semibold` mono **`amountInk`** (the colour lives
   in the label/icon/tint — the number is always ink). If unknown total
   ≠ 0, a third full-width tile in `unknownTint` labelled "CHƯA RÕ".
3. **Category card** "Theo mục": Swift Charts horizontal bars, one bar
   per category (top 6), bar colour = kind colour (data), category name
   `.callout`, value label at bar end `.callout` `.semibold` mono
   `amountInk`. Grouping keyed by kind+category (port the
   `ReportsView.categoryRows` keying — do NOT reuse `HomeView`'s
   name-only key). Chart height = 28 pt × rows.
4. **Recent card** "Gần đây": the existing `ReceiptRowView` (with §4.1
   badge + §4.1 status chip), 5 rows, dividers inset 16.
5. **Privacy line** (keep Build 1 copy verbatim) as a plain `.footnote`
   `.secondary` block under the cards, padding 16.

States:
- Empty (no receipts at all): centred icon `doc.viewfinder` 48 pt
  `.secondary`; heading `.title3` `.bold` "Chưa có hoá đơn nào"; body
  `.callout` `.secondary` "Chụp tờ đầu tiên — app tự đọc tiệm, ngày, tổng
  tiền và gợi ý Cá nhân / Business theo đuôi thẻ."; primary button
  (§4.0 neutral, height 56, radius 14) "Chụp hoá đơn đầu tiên" → Scan tab.
  To Review card and category card hidden; year card shows $0.00 tiles.
- Loading (first query): 3 skeleton rows (rounded rect 44×56 + two text
  bars, `.secondarySystemBackground`), no spinner.
- Error: not applicable (local data); if the SwiftData store fails to
  load, the app-level error card of §4.11 applies.

### 4.5 Receipt list (`ReceiptListView`)

- **Filter chips row** (horizontal scroll, height 44, padding h16, pinned
  above the list): chips per §4.1 anatomy but height 36, tappable, hit
  area 44. "Tất cả" (neutral: `.secondary` text on `unknownTint`;
  selected: white on #1C1C1E), "CÁ NHÂN" (icon+text, `personal` on
  `personalTint`; selected: white on `personal`), "BUSINESS" (same with
  business tokens), "CHƯA RÕ" (unknown tokens). Exactly one selected;
  selection also drives the toolbar menu's removal — delete the text-only
  `Menu` entirely.
- **Running total bar**: sticky card directly under the chips (opaque
  `.systemBackground`, radius 12, margin h16 v8, padding 12). Line 1:
  "Tổng {N} hoá đơn đang hiện" `.caption` `.secondary`. Line 2: two
  labelled sums, each = kind icon 14 pt in kind colour + amount
  `.callout` `.semibold` mono `amountInk`; unknown sum appended when ≠ 0.
  This bar updates with search text and chip selection (already true of
  the data; now it must LOOK designed).
- **Month header**: "{Tháng M/yyyy}" `.callout` `.bold` `.primary` left;
  right side = the same two labelled sums as the running-total bar at
  `.caption` size — icon + amount, never bare numbers (fixes finding 8).
- Rows: `ReceiptRowView` unchanged except §4.1 badge + status chip;
  row min height 68.
- States:
  - Inbox cleared (`onlyNeedsReview`, empty): trophy state — icon
    `checkmark.seal.fill` 44 pt `successFg`; heading "Đã phân loại xong
    hết ✓" `.title3` `.bold`; body "Mọi hoá đơn đều đã vào sổ chính
    thức." `.callout` `.secondary`. (Keep Build 1's exact headline copy.)
  - Search/filter no match: icon `doc.text.magnifyingglass` 40 pt;
    heading "Không thấy hoá đơn nào khớp"; body "Thử bỏ bớt chữ tìm
    hoặc chọn lại chip lọc ở trên."; text button "Xoá bộ lọc" (44 pt)
    resetting chip + search.
  - No receipts at all: same component as Home empty (§4.4) minus the
    button duplication — button "Chụp hoá đơn" → Scan tab.

### 4.6 Receipt detail (`ReceiptDetailView`)

Top-to-bottom:
1. Evidence photo: full-bleed (no list inset), height 280, `.scaledToFill`
   top-anchored with 16 pt radius bottom corners… simpler for the coder:
   photo in a card, margin 16, radius 12, height 280, tap → full-screen
   zoom sheet (`MagnifyGesture` + scroll). Missing image → placeholder
   card same size: icon `photo.badge.exclamationmark` + "Không mở được
   ảnh gốc" `.callout` + subline "Dữ liệu hoá đơn vẫn còn — chỉ thiếu
   ảnh." (never silently omit the section again).
2. Hero total block (opaque card): "TỔNG" `.caption` `.bold` `.secondary`;
   amount `.largeTitle` `.bold` mono `amountInk`; under it the §4.1 badge
   + status chip row; under that the reason line (§4.7 suggestion anatomy,
   read-only variant) when `classificationReason` is non-empty.
3. Main fields card — exactly 5 rows: Tiệm / Ngày / Thẻ (`brand •• last4`
   or "Không đọc được") / Mục / Mục đích business (Business only). Subtotal
   and Thuế move OUT of here.
4. Disclosure card "Chi tiết đầy đủ" (`DisclosureGroup`, collapsed by
   default): Subtotal, Thuế, từng món (existing item rows), mã chống
   trùng (label renamed "Mã đối chiếu chống trùng"), toàn văn đã đọc
   (OCR text, `.caption`, selectable).
5. Flags card (only when `receiptFlags` non-empty): `warningBg` opaque
   card, rows = `exclamationmark.triangle.fill` `warningFg` + text
   `.callout` in `warningFg`… text in `.primary` for readability, icon
   coloured. Keep Build 1's flag wordings verbatim.
6. Classification edit card: §4.2 picker + category menu-picker + purpose
   field (Business) + "Lưu thay đổi" secondary button (44 pt). Editing is
   the screen's ONE primary action only when status is needsReview — then
   a sticky bottom bar (opaque, top separator) holds the primary button
   (neutral, 56 pt) "Duyệt — cho vào sổ chính thức"; after approval it is
   replaced by a `successBg` banner "Đã duyệt ✓ — hoá đơn đã vào sổ
   chính thức".
7. Toolbar ••• menu (top-trailing): "Chia sẻ ảnh gốc", "Nhân bản thông
   tin" (defer if unbuilt — omit rather than fake), separator, "Xoá hoá
   đơn này" (destructive). No delete/approve buttons in the body.

### 4.7 Review (`ReviewView`) + suggestion anatomy + hero money editor

- Suggestion card (top, after the photo): opaque tint card of the
  SUGGESTED kind (radius 12, padding 12). Row: kind icon 18 pt kind
  colour + reason text `.callout` `.semibold` `.primary` — reuse the
  exact strings from `suggestClassification` ("Thẻ •• 2586 — đã đăng ký
  BUSINESS") + trailing text button "Đổi" (`.callout` `.bold`, neutral
  ink, 44 pt hit area) which scrolls to / highlights the §4.2 picker
  directly beneath the card. When kind is unknown, card uses
  `unknownTint` and the picker is expanded by default.
- Warnings card: `warningBg` anatomy as §4.6(5), heading "Anh kiểm tra
  giúp" `.headline`. Keep parser warning strings verbatim.
- Fields card: Tiệm (text field, label above), Ngày (date picker). Each
  field whose confidence < 0.85 gets: label row gains a `warningFg`
  `exclamationmark.triangle.fill` 12 pt, field background `warningBg`
  radius 8, and a caption under it — vendor: "Tên tiệm chưa chắc — anh
  nhìn ảnh gốc giúp"; date: "Ngày chưa chắc — anh kiểm tra giúp". Total
  follows the same rule via the hero editor border (2 pt `warningFg`)
  plus caption "Tổng tiền chưa chắc — anh kiểm tra giúp". Confidence is
  never printed as a raw percentage again.
- **Hero money editor** (replaces the three 110 pt fields): tapping the
  Subtotal / Thuế / TỔNG row pushes a dedicated editor view: label
  `.headline` ("TỔNG (Total)"), amount display `.largeTitle` `.bold`
  mono `amountInk` centred, `minimumScaleFactor(0.5)`; system
  `.decimalPad` keyboard; live cross-check line under the amount —
  "Subtotal + Thuế = $X — khớp tổng ✓" in `successFg`, or "… lệch $Y so
  với tổng" in `warningFg`; primary button "Xong" (neutral, 56 pt)
  returns. TỔNG row in the form shows the amount at `.title3` `.bold`
  mono with a `chevron.right` and is a 56 pt row.
- Duplicate: replace the alert with a sheet — heading "Có vẻ hoá đơn này
  đã có trong sổ" `.title3` `.bold`; the two images side by side (each
  50 % width, height 220, radius 8, labels "Ảnh mới" / "Đã lưu —
  {date}"); under each, vendor + total `.callout`; three stacked buttons
  (52 pt each): "Giữ cả hai" (neutral primary), "Chỉ giữ bản mới",
  "Chỉ giữ bản cũ" (the latter two secondary style; "Chỉ giữ bản cũ"
  discards the new scan and returns to Scan with the §4.11 success toast
  "Đã bỏ bản mới — giữ bản cũ trong sổ").
- Photo header matches detail: height 280 card (fixes the 220/320
  inconsistency).

### 4.8 Scan (`ScanView`) — async pattern

Flow change (design contract for the coder): capture → original saved →
receipt inserted immediately with processing status → Review is offered
as "Xem tờ vừa chụp" but is NEVER blocking; the user may keep scanning.

- Entry screen (designed, not a placeholder): heading `.title3` `.bold`
  "Quét hoá đơn"; body `.callout` `.secondary` (keep Build 1's explainer
  copy); primary button (neutral, 56 pt, radius 14) "Quét hoá đơn" with
  `camera.fill`; secondary button (52 pt, outlined neutral) "Chụp một
  đống (Pile)" — captures back-to-back with no Review between; tertiary
  text button (44 pt) "Chọn ảnh có sẵn". Privacy line at bottom, keep
  verbatim: "Đọc ngay trên máy — ảnh hoá đơn không rời khỏi iPhone."
- Camera guidance (custom overlay on the VisionKit preview is not
  available; implement as the pre-capture instruction card + the
  post-capture states): instruction card above the buttons cycling the
  three locked strings as the sheet's states — "Đưa hoá đơn vào khung"
  → (while OCR runs) "Đang đọc…" → "Đã chụp ✓". Where VisionKit's stock
  UI prevents overlay, show the first string on the entry screen and the
  last as the completion toast. Do not fake an overlay that isn't there.
- **Processing card** (appears on the Scan tab AND as a Home card slot
  under To Review while any receipt is processing): determinate text
  status, never a bare spinner: spinner 16 pt + "Đang đọc {done}/{total}
  tờ" `.callout` `.semibold`; progress bar `ProgressView(value:total:)`
  tinted neutral; each processing receipt listed as a row with pulsing
  thumbnail placeholder + "Đang đọc…" `warningFg` chip. On completion:
  banner card `successBg`: "Đã đọc xong {N} tờ" + if any need review,
  second line "{M} tờ cần anh xem" + button "Mở Hộp Chờ" (44 pt).
- States/errors (cards per §4.11, copy exact):
  - Camera unsupported: "Máy này không hỗ trợ quét tài liệu — anh dùng
    nút Chọn ảnh có sẵn giúp." + button "Chọn ảnh có sẵn".
  - OCR read nothing: heading "Không đọc được chữ nào"; body "Ảnh có vẻ
    mờ hoặc thiếu sáng. Anh chụp lại, để hoá đơn phẳng và đủ sáng giúp.";
    buttons "Chụp lại" (primary) / "Vẫn lưu ảnh gốc" (secondary — saves
    the receipt as needsReview with the photo as evidence).
  - Save failed: "Không lưu được ảnh gốc vào máy — anh kiểm tra dung
    lượng trống giúp." + "Thử lại".
  - Multi-page: process ALL pages; the receipt's evidence is page 1 with
    a "+{n} trang" pill on its thumbnail; pages 2+ viewable in detail's
    photo sheet.

### 4.9 Liquid Glass — iOS 26 build only (placement spec)

Glass is a CONTROL-LAYER material only (DESIGN-V2 + Apple rule). When the
iOS 26 build ships: apply `.glassEffect()` / glass button styles to —
the custom tab bar (§4.3) as one floating glass capsule, the centre CHỤP
button, navigation toolbars, the filter-chip bar (§4.5) container, the
lock screen's unlock button, and sheet grabber/action bars. NEVER glass:
year-total tiles, running-total bar, badges/chips' data fills, physical
cards, amount text of any size, receipt photos, warning/error cards —
these stay on the opaque surfaces specified above. If glass and an amount
would overlap, the amount wins and the glass element moves.

### 4.10 Cards (`CardsView`) + card anatomy + onboarding

**Physical card anatomy** (replaces `cardRow` thumbnail):
- Full-width card: width = screen − 32, aspect ratio 1.586, corner
  radius 20, solid fill = kind colour (`personal`/`business`); archived
  cards: fill desaturated via an opaque grey overlay card (#3A3A3C text
  block + "ĐÃ NGƯNG" pill), not `opacity()`.
- Inside, padding 20: top row — brand `.headline` `.semibold` white
  (left), kind icon 22 pt white (right). Middle: the chip, drawn not
  symbolised — a 36×26 pt rounded rect (radius 6), white at 0.85
  opacity, with a 1 pt inner horizontal line. Bottom row:
  `•• {last4}` `.title3` `.bold` monospaced white
  (left); kind label with icon, `.caption` `.bold` white, e.g.
  `briefcase.fill BUSINESS` (right).
- Stack: cards overlap Wallet-style — each subsequent card offset so
  only its top 72 pt strip peeks; tapping a strip raises that card to
  full and reveals under it two buttons (52 pt): "Xem hoá đơn của thẻ
  này" (neutral primary) and "Sửa / Ngưng" (secondary). Expanded card
  shows its stats line: "{N} hoá đơn · năm nay {amountInk total}".
- Destination `CardReceiptsView`: header = the full card + year-total
  card (labelled sums anatomy §4.5), body = that card's receipts reusing
  `ReceiptListView` rows + running total for the filtered set (the list
  machinery already supports this — it is a filter, not a new screen).
- Empty state (no active cards): icon `creditcard` 40 pt; heading
  "Chưa đăng ký thẻ nào"; body "Đăng ký 4 số cuối của thẻ debit — app
  sẽ tự gợi ý Cá nhân / Business cho mỗi hoá đơn trả bằng thẻ đó.";
  primary button "Thêm thẻ đầu tiên".
- `CardFormView`: keep Build 1 validation + copy, swap the segmented
  picker for §4.2, error becomes a §4.11 error card (not a red text
  section), save button becomes neutral primary 56 pt pinned at bottom.

**Onboarding** (new, Things-3 pattern — do the real thing, 3 steps, no
slideshow; shown once, flag `didOnboard`, skippable via "Để sau" 44 pt
text button on every step):
1. One sentence: heading "Sổ Hóa Đơn"; body "Chụp hoá đơn — app tự đọc
   và chia Cá nhân / Business theo đuôi thẻ debit của anh." + the two
   §4.1 badges as the only illustration. Button "Bắt đầu".
2. Register a card: the real `CardFormView` embedded, heading "Thẻ
   debit anh hay dùng nhất", prefilled with the seeded •• 2586 Business
   for confirmation ("Thẻ này đúng chưa?") since Build 1 already seeds
   it — never seed silently again without this confirmation. Button
   "Lưu thẻ này" / "Thêm thẻ khác".
3. Scan one: heading "Thử chụp 1 tờ"; body "Chọn một hoá đơn bất kỳ —
   đọc ngay trên máy, ảnh không rời khỏi iPhone."; button "Chụp thử"
   (runs the real scan flow) / "Để sau". On completion of the real
   Review save, land on Home with the §4.12 signature animation.

### 4.11 Shared state components (one implementation, used everywhere)

- `ErrorCard`: radius 12, `errorBg` opaque, padding 12; row: icon
  `exclamationmark.circle.fill` 18 pt `errorFg` + heading `.callout`
  `.bold` `.primary`; body `.callout` `.secondary`; optional action
  button row (44 pt text buttons, `errorFg` labels). Used by Scan,
  CardForm, lock-failure note (replacing the indistinguishable caption).
- `InfoNote`: same anatomy with `unknownTint` / `.secondary` icon
  `info.circle.fill` — for fail-open and informational notes, so error
  and info never share a style again (§3.8).
- Success toast: bottom floating capsule, `successBg`, icon
  `checkmark.circle.fill` `successFg` + text `.callout` `.semibold`
  `.primary`, auto-dismiss 2.5 s, `.move(edge: .bottom)` transition
  (fade under Reduce Motion). Copy patterns: "Đã lưu hoá đơn ✓",
  "Đã duyệt — hoá đơn vào sổ chính thức ✓".
- Loading: skeleton rows (as §4.4) for data waits; counted text progress
  (§4.8) for OCR; a bare indefinite `ProgressView` is banned except
  inside a button during its own action (< 1 s operations).

### 4.12 Signature animation + haptics (exactly one)

- On `ReviewView` save: the saved receipt's thumbnail (44×56) flies from
  the sheet's photo position to the Home classification tile of its kind
  via `matchedGeometryEffect`, spring `response: 0.45, dampingFraction:
  0.8` (this becomes THE app duration; all other transitions use system
  defaults), landing triggers `.sensoryFeedback(.success)` — one light
  haptic, interpreted by copy "đã cất vào sổ". Reduce Motion: 0.2 s fade,
  haptic kept. No other custom animations are introduced in Build 2.
- Approving in detail fires `.selection`→ no: approval fires the same
  `.success` haptic + §4.11 toast. Nothing else haptic except §4.2
  picker `.selection`.

### 4.13 Reports (`ReportsView`)

- Year selector: replace segmented control with a menu-picker row
  (`.menu` style `Picker`, 44 pt row, "Năm thuế" label + year +
  chevron) — scales to many years.
- **"Năm thuế {year} nhìn lại" hero card**: heading `.title3` `.bold`;
  two labelled totals (anatomy §4.5 line 2 at `.title3` size); the
  §4.4(3) category chart for the year; footer line "{N} hoá đơn · {M}
  tờ đang chờ duyệt". This card is specified as the future PDF cover —
  build it as a self-contained view (`TaxYearSummaryCard`) so the export
  can render it unchanged.
- Tax-readiness warning (when pending or unknown > 0): `warningBg` card —
  "Còn {M} tờ chưa phân loại / chờ duyệt — xuất hồ sơ bây giờ sẽ thiếu
  các tờ này." + button "Mở Hộp Chờ" (44 pt).
- Export card (when Tax Pack lands; in Build 2 show the card with the
  three rows ENABLED only if the feature is built — never show dead
  buttons): three rows 56 pt, icon + label + chevron: "Xuất PDF (bảng +
  ảnh gốc)", "Xuất CSV cho người làm thuế", "Xuất ZIP tất cả ảnh gốc".
  Until then, keep Build 1's honest footnote and omit the card.
- Empty year: §4.5 no-match component with heading "Năm {year} chưa có
  hoá đơn nào" and body "Anh chọn năm khác hoặc quét thêm hoá đơn."

### 4.14 Lock screen (`ContentView.lockScreen`)

- Opaque `.systemBackground`; centred column, spacing 16, top spacer:
  app mark — rounded-rect 72×72 in `personalTint`… no classification
  colour for branding: neutral mark, `primaryButtonBg` rounded rect
  radius 18 with `doc.text.fill` white 34 pt; "Sổ Hóa Đơn" `.title`
  `.bold`; subline `.callout` `.secondary` "Hoá đơn của anh được khoá
  bằng Face ID"; `faceid` symbol 40 pt `.primary` (replaces `lock.fill`);
  primary button (neutral, 56 pt, margin h32) "Mở khoá"; privacy caption
  `.footnote` `.secondary` at the bottom: "Đọc ngay trên máy — ảnh hoá
  đơn không rời khỏi iPhone."
- Fail-open note → `InfoNote` (§4.11); auth-failure note → `ErrorCard`
  (§4.11) with the existing copy and a "Thử lại" action. States are now
  visually distinct.

---

## 5. Checkpoint tally (basis for the counts in the header)

✓ = 20: foundation #1, #2, #3, #6 · To Review position (§3.1) · year-total
separation (§3.1) · recent list (§3.1) · month grouping (§3.2) · running
total (§3.2) · full-text search (§3.2) · detail data table (§3.3) · detail
flags (§3.3) · suggestion reason (§3.4) · suggestion override (§3.4) ·
Review warnings (§3.4) · VisionKit scanner (§3.5) · scan privacy copy
(§3.5) · card add/edit/archive + kind-change dialog (§3.6) · Reports
preview table (§3.9) · 5-tab structure (§3.7) · Face ID fail-open +
retry (§3.8).

◐ = 11 (partial/bare): badge 4th signal · Dynamic Type · 4/8 grid/tokens ·
Home empty state · list empty states · detail image treatment · scan
status text · scan error presentation · physical-card drawing · lock
screen design · designed-states coverage overall.

✗ = 23 (missing/failing): amounts primary+opaque in tiles/running total ·
touch ≥44 pt · one-colour-everywhere surfaces (chips/chart/PDF absent) ·
neutral primary buttons · To Review card design · Home chart · pinnable
modules · month-header signals · filter chips · progressive disclosure ·
detail ••• menu · hero total · hero money editor · per-field confidence ·
duplicate comparison · async/background scanning · counted processing
status · scanner guidance states · Pile Mode · tap-card-to-receipts ·
Cards empty state · Tax Year look-back + Tax Pack · centre CHỤP anchor ·
onboarding · signature animation/haptics.

Total: 20 + 11 + 23 = 54 checkpoints. Complies 20 / bare-or-missing 34.

*End of audit. No app code was modified.*

---

## LEADER NOTE — 2026-11-08 23:24 CST (reprioritization after Field Test 2)

The user's verdict on a real crumpled paper receipt ("Chất lượng scan dữ
liệu rất tệ" / "Thua các app chính thức rất nhiều") reorders Build 2:
READING QUALITY is now the centerpiece (engine evaluation + preprocessing
+ PDF text layer + the 001/002/003 scorecard gate — see QA-VERDICT.md
Appendix B and CODE-AUDIT Leader Addendum #2). This audit's findings and
the §4 spec remain valid and unchanged, but they are SEQUENCED AFTER the
reading engine in the combined Build 2 list. One design consequence worth
carrying into the engine work: when the engine cannot read a field, the
Review screen's per-field confidence display and in-place editing (already
specified in §4) become the safety net the user actually touches — they
move up with Tier 0, not with the polish tier.
