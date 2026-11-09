# CODE AUDIT — Sổ Hóa Đơn, Build 1 (Mission 1, independent senior iOS review)

Auditor: Senior iOS Code Specialist (independent review). Audit only — no code was modified.
Ground truth: all 8 Swift files + `project.yml` in `~/workspace/receipt-app/build1/`
(2,387 lines total), read in full; every line number below is from `nl -ba` on those files.
Laws checked against: `TEAM.md` (basic-mistakes catalogue #1–#4), `BLUEPRINT.md`,
`VENDOR-FORMATS.md`, and the claims in `build1/BUILD1-NOTES.md`.

**No compiler exists in this local environment** (no `swiftc`/`xcodebuild` — verified
by shell), so the first draft of this audit labelled compile questions UNVERIFIED.
**That gap was closed mid-audit by field evidence (2026-11-08 23:18 CST): the cloud
build of Build 1 as pushed (commit dba8693) SUCCEEDED under Xcode 16 / macOS-15 —
the code as pushed compiles.** Compile confidence below is therefore settled by
evidence, and the one potential compile finding (old B-1, tuple key-paths) is
honestly reconciled as RETRACTED in §B-1 and in the final statement.

**Field evidence folded into this audit (user's real device, screenshot-observed;
framing corrected by the user 2026-11-08 23:19 CST, superseding an earlier
"thermal paper" description):** the user **imported the ORIGINAL FILE downloaded
from Sam's Club** — the crisp digital receipt rendering, the same class of source
whose hand transcription the parser prototype passed 100%. The Review screen showed —
vendor "Sam's Club" ✓, date Oct 29 2026 5:49 PM ✓ (the AM/PM fix works in the field),
card "Mastercard •• 2586" ✓, # ITEMS SOLD 15 ✓ — **but subtotal / tax / total ALL
EMPTY (nil), no item amounts attached anywhere, and `validate()` reported quantity
sum 0 vs 15 sold.** The parser discipline held in the field (see §F preamble):
warnings fired, nothing was invented, the receipt lands in `needsReview`.
**"Thermal-paper garbling" is therefore DROPPED as a candidate cause.** The live
candidate mechanisms — still **INFERENCE**, unproven until the raw OCR text exists
(F3) — are in the real Vision OCR layer on a very tall, narrow digital receipt
image: column-splitting of right-aligned amounts into separate observations,
and/or resolution loss from downscaling. §F gives the revised Build-2 priorities:
(#1) PDF import with text-layer extraction, (#2) OCR row-merge + split-line parser
tolerance + tall-image handling, (#3) the raw-OCR viewer.

Severity: **BLOCKER** = will not compile or will crash · **MAJOR** = wrong behaviour or
data risk · **MINOR** = polish / latent. F1/F2 are MAJOR by that definition and
**release-blocking** in practice: the app's core read failed on its reference receipt.

---

# A. VERDICTS ON THE 4 CLAIMED FIXES

## Fix (i) — `Parser.swift` `findDateTime`: `Int?` → `Int` + AM/PM — ✅ PRESENT AND CORRECT (one minor residue, see C-14)

Evidence, `Parser.swift:333-348`:

```swift
private static func findDateTime(in lines: [OCRLine]) -> (date: Date, confidence: Double)? {
    for line in lines {
        if let m = matchGroups(line.text, pattern: #"(\d{1,2})/(\d{1,2})/(\d{2,4})\s+(\d{1,2}):(\d{2})\s*([AP]M)?"#), m.count == 6 {
            // Xử lý AM/PM: "5:49 PM" phải thành 17:49, kẻo giờ bị lệch 12 tiếng.
            var hour = Int(m[3] ?? "") ?? 0
            if let ampm = m[5]?.uppercased() {
                if ampm == "PM" && hour < 12 { hour += 12 }
                if ampm == "AM" && hour == 12 { hour = 0 }
            }
            if let d = makeDate(month: Int(m[0] ?? ""), day: Int(m[1] ?? ""), year: Int(m[2] ?? ""),
                                hour: hour, minute: Int(m[4] ?? "") ?? 0) {
```

- The original compile error is genuinely gone: `hour` is a non-optional `Int`
  (`Int(...) ?? 0`, L337) and `minute:` receives `Int(m[4] ?? "") ?? 0` (L343), both
  matching `makeDate(month:day:year:hour:minute:)` where `hour`/`minute` are `Int`
  (`Parser.swift:372`). Note `month/day/year` are still passed as `Int?` — that is
  **correct**, because `makeDate` declares those three parameters as `Int?` (L372).
- AM/PM logic is correct in all four quadrants: PM & hour<12 → +12; AM & hour==12 → 0;
  PM & hour==12 → stays 12; AM & hour<12 → unchanged. Case-insensitivity is real:
  `regex()` builds every pattern with `.caseInsensitive` (`Parser.swift:461`), and
  the captured marker is `.uppercased()` before comparison (L338).
- Residue (not part of the claim, filed as MINOR C-14): `makeDate` never range-checks
  `hour`/`minute`, and `Calendar.date(from:)` normalises impossible dates
  (e.g. Feb 31 → early March) instead of rejecting them.
- **Field confirmation (2026-11-08 23:18 CST):** the imported Sam's Club file read
  back "Oct 29 2026 5:49 PM" — correct hour, correct AM/PM — on the user's device.
  This fix is not just present in source; it is proven in the field.

## Fix (ii) — `ReceiptViews.swift` `checkDuplicate`: `#Predicate` on `String?` → fetch + in-memory filter — ✅ PRESENT AND CORRECT, with a fail-open hole (MAJOR B-5)

Evidence, `ReceiptViews.swift:560-566`:

```swift
private func checkDuplicate() {
    guard let key = draft.result.dedupeKey else { duplicateCount = 0; return }
    // Lọc trong bộ nhớ thay cho #Predicate so sánh String? — loại bỏ điểm
    // rủi ro biên dịch với macro predicate trên cột optional (đã xử lý khi duyệt).
    let all = (try? modelContext.fetch(FetchDescriptor<Receipt>())) ?? []
    duplicateCount = all.filter { $0.dedupeKey == key }.count
}
```

- No `#Predicate` remains anywhere in Build 1 (grep over all 8 files: the only two
  hits for "Predicate" are these explanatory comments, here and `CardsView.swift:161`).
- The comparison itself is type-correct: `Receipt.dedupeKey` is `String?`
  (`Models.swift:113`), `key` is `String`; `Optional == String` is a valid overload.
- Hole: `try? … ?? []` makes a fetch failure indistinguishable from "no duplicates" —
  duplicate protection silently switches off exactly when the store is unhealthy.
  Filed as MAJOR B-5; the fix itself is not at fault, the error handling is.

## Fix (iii) — `CardsView.swift` `applyCardChange`: same predicate replacement — ✅ PRESENT AND CORRECT as a replacement (the surrounding logic has separate MAJORs, C-8)

Evidence, `CardsView.swift:156-169`:

```swift
private func applyCardChange(_ pending: PendingKindChange, reclassifyOld: Bool) {
    pending.card.brand = pending.brand
    pending.card.kind = pending.kind
    if reclassifyOld {
        let last4 = pending.last4
        // Lọc trong bộ nhớ thay cho #Predicate (tránh phụ thuộc macro với optional).
        let all = (try? modelContext.fetch(FetchDescriptor<Receipt>())) ?? []
        for receipt in all where receipt.cardLast4 == last4 {
            receipt.classification = pending.kind
            receipt.classificationReason = "Xếp lại theo thẻ •• \(last4) — anh chọn đổi cả hoá đơn cũ"
        }
    }
    try? modelContext.save()
}
```

- Replacement is present, compiles as written, and only runs the rewrite when the
  user explicitly chose "Xếp lại cả hoá đơn cũ" in the confirmation dialog
  (`CardsView.swift:74-94` region: dialog with "Chỉ áp dụng từ nay" / "Xếp lại…") —
  so the snapshot law's *consent* requirement is honoured.
- What the replacement does **not** fix is filed separately: fetch fail-open (B-5),
  and reclassification side-effects — it rewrites reviewed/manually-classified
  receipts too, and leaves category / purpose / status inconsistent (C-8).

## Fix (iv) — `ScanView.swift`: EXIF orientation normalisation before OCR — ⚠️ PRESENT BUT INCOMPLETE / LATENTLY DANGEROUS (MAJOR B-4)

Evidence, `ScanView.swift:167-180`:

```swift
private func recognizeLines(in image: UIImage, completion: @escaping ([OCRLine]) -> Void) {
    // Chuẩn hoá hướng ảnh trước khi OCR: ảnh từ thư viện có thể mang hướng EXIF
    // mà cgImage bỏ qua — không chuẩn hoá thì Vision đọc chữ bị xoay, ra rác.
    let upright: UIImage
    if image.imageOrientation == .up {
        upright = image
    } else {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        upright = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
    }
    guard let cgImage = upright.cgImage else {
        completion([])
        return
    }
```

- The idea and placement are right: normalisation happens before
  `VNImageRequestHandler(cgImage:options:)` (`ScanView.swift:196`), and the
  `VNImageRequestHandler` is given no `orientation:` argument, so a pre-baked
  upright bitmap is the correct strategy.
- **Defect:** `UIGraphicsImageRenderer(size:)` uses the renderer's default format,
  whose `scale` is the main screen's scale (2×/3×), not the image's. For a Photos
  image, `image.size` is in points at scale 1 (e.g. 4032×3024 pt for a 12 MP photo),
  so the renderer tries to allocate a ~12096×9072 bitmap (≈ 440 MB of BGRA) —
  jetsam/OOM risk, or a silently huge intermediate, on exactly the path this fix
  exists for (rotated library photos). Document-camera images normally arrive
  `.up`, so the main scan path does not hit it — which is why this can pass a
  first device test and still be wrong. Corrected code in B-4.
- Secondary gap: an image backed only by a `CIImage` (no `cgImage`) falls into
  `completion([])` → the user is told "no text found," with the real cause hidden.

---

# F. FIELD-PROVEN FINDINGS — TOP SEVERITY (from the 2026-11-08 23:18 CST device test, framing corrected 23:19 CST)

**What the field test proved, before the failures — credit where it is due.**
On a real Sam's Club receipt the app read vendor, date/time (with correct AM/PM),
card brand + last-4, and # ITEMS SOLD correctly. When the money fields failed,
the BLUEPRINT discipline worked exactly as designed: `validate()`
(`Parser.swift:387-420`) fired "Không đọc được TỔNG TIỀN" and the quantity
mismatch (0 read vs 15 sold), **no figure was silently invented or "repaired,"**
and the receipt was headed for `needsReview`, not the official book. That is
global law 1 (flag, never rewrite) holding under real failure — the strongest
positive evidence Build 1 has produced.

**Leader-verified code premise (checked by the team leader, cited here):**
`ScanView.swift:181-190` maps `VNRecognizedTextObservation`s 1:1 into
`OCRLine`s, sorted only by `boundingBox.maxY` descending — **no row-grouping by
vertical overlap, no X-ordering within a visual row** — while `Parser.swift`'s
Sam's patterns are anchored single-line (label and amount must share one line:
`Parser.swift:168,171-176,177-180`; item amounts must trail the item text:
`Parser.swift:424-431`). Grep over `build1/*.swift` finds **zero PDF support**
(no `PDFKit`/`PDFDocument` anywhere) and the **only import path is
`PhotosPicker matching: .images`** (`ScanView.swift:121`) — a downloaded Sam's
PDF cannot even be selected in Build 1, and there is no Files/Share-Sheet
import at all. (BLUEPRINT §3 always specified Print→PDF→Share/Files as the
Sam's import route; Build 1 did not build it — see BUILD1-NOTES "intentionally
absent" list, where PDF import was deferred to a later build. The field test
shows that deferral was the wrong call for the user's actual Sam's workflow.)

**INFERENCE (labelled, not proven):** the money loss mechanism lives in the
real Vision OCR layer on this very tall, narrow digital receipt image —
right-column amounts returned as separate observations from their labels
(column-splitting) and/or downscaling of the extreme-aspect image before
recognition. It **cannot** be confirmed from Build 1, because Build 1 displays
the raw OCR text nowhere in the UI (F3). Thermal garbling is excluded: the
source was a crisp digital file.

## F1. MAJOR (release-blocking; Build-2 priority #1) — No PDF import and no text-layer extraction: the app's primary Sam's source is forced through its weakest path (OCR), or cannot be imported at all

- Files/lines: absence is the finding — zero `PDFKit` hits in `build1/*.swift`;
  the only intake is `ScanView.swift:121` (`.photosPicker(…, matching: .images)`)
  and the document camera (`ScanView.swift:103-120`). A PDF selected nowhere
  can reach neither `ReceiptParser` nor `ImageStore`.
- Why it outranks the OCR fixes: Sam's downloaded receipts are **digitally
  generated**. If the file is a PDF with an embedded text layer, its text is
  *exact* — the same fidelity the prototype passed 100% on — and OCR of any
  quality is strictly worse. Routing the best source through the worst
  pipeline is an architecture error, not an OCR-tuning problem.
- Exact fix (concrete spec):
  1. **Intake:** add a Files import (`fileImporter` for *files* — note: the
     Test-0 failure was picking the app's *own folder*; file-picking is a
     different mode and still needs its own one-test device check per
     TEAM.md #3) **and** a Share-Sheet/`onOpenURL` + document-type
     declaration in `project.yml` (`UTImportedTypeDeclarations` /
     `CFBundleDocumentTypes` for `com.adobe.pdf` and public images), accepting
     **multiple files** (Sam's batch downloads, BLUEPRINT §3/V1.1). Accepted
     types: `.pdf`, `.jpeg`, `.png`, `.heic`. Security-scoped resources must
     be opened with `startAccessingSecurityScopedResource()` and always
     stopped — the classic leak here is a hard failure on the second import.
  2. **Hook point:** one new intake function in `ScanView.swift` beside
     `process(image:)` (`ScanView.swift:142`) —
     `processImportedFile(url:)` — which branches: PDF → text-layer path;
     image → existing `process(image:)` (with F2 applied). Each imported file
     produces its own `ScanDraft`/Review, sequentially.
  3. **Text-layer extraction (PDFKit, iOS 11+ — no availability issue):**
     ```swift
     import PDFKit
     func ocrLinesFromTextLayer(pdfURL: URL) -> [OCRLine]? {
         guard let doc = PDFDocument(url: pdfURL) else { return nil }
         var lines: [OCRLine] = []
         for i in 0..<doc.pageCount {
             guard let page = doc.page(at: i), let text = page.string else { continue }
             for raw in text.components(separatedBy: .newlines) {
                 let t = raw.trimmingCharacters(in: .whitespaces)
                 if !t.isEmpty { lines.append(OCRLine(text: t, confidence: 1.0)) }
             }
         }
         return lines.isEmpty ? nil : lines
     }
     ```
     Feed the result to the **same** `ReceiptParser.parse(lines:)` — no second
     parser. `PDFDocument.page.string` preserves the PDF's content-stream
     order, which for Sam's generated receipts is reading order; if a real
     file shows column-interleaved text-layer lines, that is exactly what F2's
     split-line tolerance is for — do not build a second layout engine before
     the fixture (below) proves one is needed.
  4. **Confidence policy for text-layer lines (recommendation): `1.0`.**
     Embedded text is not a recognition guess; stamping it 1.0 makes
     `validate()`'s confidence warnings (`Parser.swift:412-418`) correctly
     silent for digital imports while cross-checks (Σ items vs subtotal,
     subtotal+tax vs total) still run at full strength — a text-layer receipt
     that doesn't add up is still flagged, never trusted blindly. Do **not**
     stamp a mid value like 0.85: that would park every clean digital import
     in needsReview for a confidence problem it does not have.
  5. **Evidence image:** a PDF import must still store proof. Save the
     original PDF file into `ReceiptImages` (extend `ImageStore` with a
     file-copy save, and store the extension in `imageFileName` — today
     `ImageStore.load` assumes JPEG, `Models.swift:265-270`, so the detail
     view must branch: PDF → render page 1 via `PDFPage.thumbnail` for
     display) or, minimally, render each page to JPEG at ≥200 dpi and store
     those. The original file bytes are the better evidence; rendering is
     the acceptable fallback. Either way this choice must be explicit in
     Build 2's notes, not emergent.
  6. **Fallback:** a PDF with **no** text layer (scanned-image PDF) returns
     `nil` from the extractor → render pages to images → F2 OCR path. Never
     treat "PDF opened" as "text extracted."

## F2. MAJOR (release-blocking; Build-2 priority #2) — OCR lines are observations, not rows; the parser demands single-line label+amount; very tall images get no special handling

Three linked defects, one fix programme. Applies to all *image* inputs
(camera, Photos, rendered/no-text-layer PDFs).

### F2a. No row-merge in `ScanView` — `ScanView.swift:181-190`

Current code (leader-verified premise, quoted in §F preamble): observations
sorted by `maxY` only, emitted 1:1. If Vision returns "SUBTOTAL" and "203.30"
as two observations on the same visual row, the parser receives two lines and
every anchored money pattern misses — consistent with the field result
(labels, card and items-sold read fine; every amount vanished).

Exact fix — group by vertical overlap, order by X, join, then sort rows:

```swift
// Replace the body of the VNRecognizeTextRequest completion (ScanView.swift:181-190).
let observations = (req.results ?? []).compactMap { $0 as? VNRecognizedTextObservation }
// 1. One fragment per observation, keeping its box.
struct Frag { var text: String; var confidence: Float; var box: CGRect }
var frags: [Frag] = observations.compactMap { obs in
    guard let c = obs.topCandidates(1).first else { return nil }
    return Frag(text: c.string, confidence: c.confidence, box: obs.boundingBox)
}
// 2. Sort top→bottom (Vision origin is bottom-left: larger maxY = higher),
//    then greedily group fragments whose Y ranges overlap ≥50% of the
//    shorter fragment's height into one visual row.
frags.sort { $0.box.maxY > $1.box.maxY }
var rows: [[Frag]] = []
for f in frags {
    if var row = rows.last,
       let anchor = row.first {
        let overlap = min(f.box.maxY, anchor.box.maxY) - max(f.box.minY, anchor.box.minY)
        let shorter = min(f.box.height, anchor.box.height)
        if shorter > 0 && overlap / shorter >= 0.5 {
            row.append(f); rows[rows.count - 1] = row; continue
        }
    }
    rows.append([f])
}
// 3. Within a row: left→right by minX, joined with a single space.
//    Confidence of a merged line = MINIMUM of its fragments (the weakest
//    fragment bounds how much the joined line can be trusted — an average
//    would let a garbled amount hide behind a crisp label).
let lines: [OCRLine] = rows.map { row in
    let sorted = row.sorted { $0.box.minX < $1.box.minX }
    return OCRLine(text: sorted.map(\.text).joined(separator: " "),
                   confidence: Double(sorted.map(\.confidence).min() ?? 0))
}
completion(lines)
```

Rows remain in top→bottom order because step 2 consumes fragments already
sorted that way and only ever appends to the last open row. The 50%-of-shorter
threshold is the standard line-grouping rule; it must be validated against
the archived fixture (§F acceptance), not re-tuned blind.

### F2b. Parser has zero tolerance for label/amount split across lines — `Parser.swift:165-204` (Sam's), `240-276` (generic)

Even with F2a, a row can still split (amount dropped to the next visual row
on a skewed render). The totals loops must become a small state machine:
when a line is *only* a label, remember it for exactly one following line.

Exact fix — Sam's branch (generic branch identically, with its own patterns):

```swift
// State carried across the totals loop in parseSams:
var pendingLabel: String? = nil   // "SUBTOTAL" | "TAX1" | "TAX2" | "TOTAL" | "ITEMLINE"
for line in lines {
    let text = line.text
    // Amount-only line completes a pending label.
    if let label = pendingLabel,
       let m = matchGroups(text, pattern: #"^\$?(\d[\d,]*\.\d{2})(-)?$"#) {
        let cents = moneyToCents(m[0] ?? "", negative: m[1] != nil)
        switch label {
        case "SUBTOTAL": r.subtotalCents = cents
        case "TOTAL":    r.totalCents = cents; r.totalConfidence = line.confidence
        default:         r.taxes.append(ParsedTaxLine(label: label, rateText: nil, amountCents: cents))
        }
        pendingLabel = nil
        continue
    }
    if let lm = matchGroups(text, pattern: #"^(SUBTOTAL|TOTAL|TAX\s+(\d)(?:\s+[\d.]+\s*%)?)$"#) {
        pendingLabel = (lm[0] ?? "").replacingOccurrences(of: " ", with: "")
        if pendingLabel == "TAX" { pendingLabel = "TAX" + (lm[1] ?? "") } // normalise TAX 1 → "TAX1"
        continue
    }
    pendingLabel = nil   // any other line expires the pending label — one line of grace, never two
    … existing single-line patterns unchanged …
}
```

And the item-side equivalent in the Sam's item loop (`Parser.swift:143-160`):
an item line that ends **without** a trailing amount already creates
`pending` — an amount-only next line (`^\$?(\d[\d,]*\.\d{2})(-)?\s*([YT])?$`)
must complete that pending item (set `amountCents`/`unitPriceCents`/`taxFlag`,
append, clear) instead of falling through as an unrecognised line. This is
the item-level analogue of the existing qty-line completion
(`Parser.swift:119-127`) and reuses its shape.
**Guardrail — what this must NOT do:** it changes *where amounts may be
found*, never *how they are judged*. `validate()` is untouched: a
split-line total that contradicts subtotal+tax is still only flagged
(`Parser.swift:401-405`), and a pending label that never completes leaves
the field `nil` → the existing "Không đọc được TỔNG TIỀN" warning and
needsReview. One line of grace only — a label must never reach across an
intervening text line to grab a distant amount (that is how footer numbers
would get promoted into totals; see also C-5).

### F2c. Very tall, narrow images: no aspect-ratio handling before OCR — `ScanView.swift:196-203`

The failing source is a full-length Sam's receipt rendering: extreme height,
small type relative to the canvas. A single `VNImageRequestHandler` pass over
such an image is exactly where small right-column figures get merged, split,
or lost (INFERENCE as to this specific failure; the *absence* of any handling
is fact — the handler is created once, at native size, `ScanView.swift:196`).

Specified handling (not optional polish — part of this finding's fix):
if `image.height / image.width > 3.0`, slice the (already
orientation-normalised, B-4) image into vertical tiles of ≈1600 px height
with **200 px overlap** between consecutive tiles, run the OCR request per
tile, offset each observation's `boundingBox` Y by the tile's origin
(converted into the full image's normalised coordinate space) **before**
F2a's row-merge, and drop duplicate fragments produced inside overlap bands
(same text, Y within one line-height of the band boundary → keep the
higher-confidence copy). Tiling bounds per-request pixel dimensions so
Vision's internal downscaling stops being the resolution ceiling.
Threshold and tile size are starting values to be validated on the fixture,
and the tile path must be exercised by the acceptance test — not shipped
untested alongside it.

## F3. MAJOR (Build-2 priority #3) — The raw OCR text exists in the data model and is displayed nowhere: the app cannot be diagnosed

- The data is already captured end-to-end: `ParseResult.rawText`
  (`Parser.swift:47,74-84`) is stored on save as `Receipt.ocrRawText`
  (`ReceiptViews.swift:595`; model field `Models.swift:124`) — and no view
  in Build 1 ever renders either string (grep: `ocrRawText` is read only by
  list *search*, `ReceiptViews.swift:118`). The one artefact that would have
  distinguished column-splitting from downscaling from text-layer absence in
  the 23:18 failure was on the device, invisible.
- This is TEAM.md mistake #4 in product form: without primary evidence, every
  OCR failure becomes a guessing exercise — as this audit's own INFERENCE
  labels demonstrate.
- Exact fix:
  1. **ReviewView** (`ReceiptViews.swift:420-435`, directly under the
     original-image section): a collapsed-by-default section —
     ```swift
     DisclosureGroup("Văn bản OCR gốc") {
         Text(draft.result.rawText)
             .font(.caption.monospaced())
             .textSelection(.enabled)
     }
     ```
  2. **ReceiptDetailView** (`ReceiptViews.swift:245-262`, after the
     "Thông tin" section): the same disclosure bound to
     `receipt.ocrRawText`, hidden only when the string is empty.
  3. For PDF text-layer imports (F1), show the extracted text in the same
     place, headed "Văn bản trong PDF (text layer)" — same viewer, honest
     label about which pipeline produced it. `textSelection(.enabled)` in
     both, so the user can copy the exact evidence out for a bug report.

## §F acceptance test (binding for Build 2 — replaces any earlier wording)

The user will send the actual downloaded Sam's file; when it arrives it is
archived under `~/workspace/receipt-app/samples/` and becomes THE fixture.
**Status at audit time: the file has NOT yet arrived — fixture PENDING; no
result in this section has been run.**
Against that file — through its PDF text layer if it is a PDF (F1), and
through its real Vision OCR output if it is / is rendered to an image (F2) —
the app must auto-read, with no hand entry: **subtotal 203.30 · taxes
9.60 + 3.90 · total 216.80 · 10 line items with amounts summing to the
subtotal · 15 items sold.** Anything less is not "OCR is imperfect" — it is
this finding still open, and the raw-text viewer (F3) must be used to say
which stage lost the numbers before any further fix is attempted.

---

# B. FINDINGS — COMPILE & RUNTIME/CRASH (ordered by severity)

## B-1. RETRACTED — `ForEach(id:)` with key paths into tuple elements, 4 sites — ⚠️ flagged as a potential BLOCKER in this audit's first draft; the evidence has since refuted it

Sites: `HomeView.swift:76` (`id: \.name`), `HomeView.swift:226` (`id: \.name`),
`ReceiptViews.swift:170` (`id: \.key`), `ReceiptViews.swift:498` (`id: \.offset`).

First-draft reasoning, for the record: Swift has no *general* key-path support
for tuple members (`array.map(\.name)` on a labelled-tuple array does not
compile), so I flagged SwiftUI's `id:` key paths into tuple elements as an
UNVERIFIED potential compile blocker and recommended converting the four sites
to `Identifiable` structs pre-emptively.

**Reconciliation (honest, per TEAM.md): the cloud build of Build 1 as pushed
(commit dba8693) SUCCEEDED under Xcode 16 / macOS-15.** The compiler accepted
all four sites. The finding is therefore **withdrawn as a compile finding —
it was wrong to keep it at BLOCKER severity once the build evidence existed,
and it is not carried as an open compile risk in any form.** (SwiftUI's `id:`
key path into a tuple element evidently compiles in this toolchain even though
the general tuple key-path case does not; the compiler is the authority, and
it has spoken.) No fix is required. The struct conversion remains available
purely as a readability preference — it is **not** a gate item, and no reader
of this audit should spend Build-2 time on it as a "compile fix." Two genuine
issues that happen to live on two of these same lines are unrelated to
key paths and remain open on their own merits: the `id: \.name` *value
collision* in ReportsView (C-16) and Home's cross-kind category merge (C-12).

## B-2. MAJOR — Every `modelContext.save()` is `try?`, and the UI declares success unconditionally — receipts can be silently lost

Sites: `ReceiptViews.swift:617-618` (Review save), `ReceiptViews.swift:368-377`
(detail `saveChanges`), `ReceiptViews.swift:334-338` (Duyệt), `ReceiptViews.swift:353-357`
(delete), `CardsView.swift:132,144,152,168`, `ContentView.swift:122-129`.

Worst case, `ReceiptViews.swift:577-618` (abridged):

```swift
modelContext.insert(receipt)
for (index, parsed) in draft.result.items.enumerated() { … modelContext.insert(item) }
try? modelContext.save()
onDone()                       // sheet dismisses either way — user believes it saved
```

And `ReceiptViews.swift:376-377`:

```swift
try? modelContext.save()
savedNote = true               // "Đã lưu ✓" is shown even if the save threw
```

A failed save (store error, constraint fault) leaves no receipt, no error, and a
dismissed Review sheet — while the one JPEG was already written (`ScanView.swift:143`),
so the store and the image folder silently diverge. This is TEAM.md mistake #4's
mirror image: no log, no evidence, conclusion ("saved") without proof.
Saving is the app's single non-replaceable action; it must not be the one place
errors are swallowed.

Exact fix (Review path; mirror it in the other sites):

```swift
do {
    try modelContext.save()
    onDone()
} catch {
    saveErrorText = "Không lưu được hoá đơn (\(error.localizedDescription)). Anh thử lại giúp — ảnh gốc vẫn còn."
}
```

## B-3. MAJOR — Full-size image decode, synchronously, on the main thread, inside every list row

`ReceiptViews.swift:60-72` (`ReceiptRowView.body`):

```swift
if let image = ImageStore.load(fileName: receipt.imageFileName) {
    Image(uiImage: image).resizable().scaledToFill().frame(width: 44, height: 56) …
```

`ImageStore.load` is `Data(contentsOf:)` + `UIImage(data:)` at native resolution
(`Models.swift:265-270`). A 44×56 pt thumbnail therefore costs a full 12–24 MP
decode (≈ 50–100 MB transient) **per row, per body evaluation**, on the main
thread — the same code is also in the detail view (`ReceiptViews.swift:249`) and
Review (`ReceiptViews.swift:424`), where full size is at least wanted. In a
scrolling list this is the classic jank/jetsam profile, and it contradicts the
project's measured-smoothness standard. No cache, no downsampling anywhere.

Exact fix — add a thumbnail path to `ImageStore` (ImageIO downsampling, no full decode):

```swift
static func thumbnail(fileName: String, maxPixel: Int = 168) -> UIImage? {
    guard !fileName.isEmpty else { return nil }
    let url = directory.appendingPathComponent(fileName)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let opts: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixel
    ]
    guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
    return UIImage(cgImage: cg)
}
```

…and call `ImageStore.thumbnail(...)` from `ReceiptRowView` only.

## B-4. MAJOR — EXIF fix's renderer can allocate a ~3×-scale bitmap (see Fix iv)

`ScanView.swift:174-175`. Exact fix — pin the format to scale 1:

```swift
let format = UIGraphicsImageRendererFormat()
format.scale = 1
format.opaque = true
let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
upright = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
```

Also cap the OCR input size (Vision gains nothing past ~3000 px on the long edge)
before creating the handler at `ScanView.swift:196` — this bounds both memory and
OCR time on 24 MP library photos.

## B-5. MAJOR — Fetches fail open everywhere: duplicate check, card reclassify, and the starter-card seed

- `ReceiptViews.swift:564` — `let all = (try? modelContext.fetch(…)) ?? []` →
  fetch error ⇒ `duplicateCount = 0` ⇒ a known TC# duplicate saves with no alert.
- `CardsView.swift:162` — same pattern in `applyCardChange` ⇒ fetch error ⇒
  "reclassify old receipts" silently reclassifies **none** of them, while the card
  itself is changed — the exact split-brain the dialog exists to prevent.
- `ContentView.swift:121-131` — seed:

```swift
let existing = (try? modelContext.fetch(descriptor)) ?? []
if existing.isEmpty { … modelContext.insert(card); try? modelContext.save() }
defaults.set(true, forKey: "didSeedStarterCard2586")
```

  Fetch error ⇒ `existing` reads as empty ⇒ a second `2586` CardTail is inserted
  on top of the user's real cards. And the `didSeed…` flag is set to `true`
  **even if the insert/save failed**, so a failed seed can never retry.

Exact fix: distinguish failure from empty, and only set the flag after a verified save:

```swift
guard let existing = try? modelContext.fetch(descriptor) else { return } // retry next launch; do NOT set the flag
if existing.isEmpty {
    modelContext.insert(card)
    do { try modelContext.save(); defaults.set(true, forKey: "didSeedStarterCard2586") }
    catch { /* leave flag unset */ }
} else {
    defaults.set(true, forKey: "didSeedStarterCard2586")
}
```

For the two fetch sites, surface the failure (block the save / the reclassify with
an alert) rather than treating it as zero rows.

## B-6. MAJOR — Receipt deletion destroys the evidence image *before* the database delete is confirmed

`ReceiptViews.swift:353-360`:

```swift
Button("Xoá", role: .destructive) {
    ImageStore.delete(fileName: receipt.imageFileName)   // evidence gone first
    modelContext.delete(receipt)
    try? modelContext.save()                             // if this throws…
    dismiss()
}
```

If the save fails, the app keeps a receipt whose original image — the IRS proof,
per BLUEPRINT §4 — is already deleted. That ordering is backwards for the one
file in the app that is irreplaceable.

Exact fix:

```swift
Button("Xoá", role: .destructive) {
    let fileName = receipt.imageFileName
    modelContext.delete(receipt)
    do {
        try modelContext.save()
        ImageStore.delete(fileName: fileName)   // only after the delete is durable
        dismiss()
    } catch {
        deleteErrorText = "Chưa xoá được (\(error.localizedDescription))."
    }
}
```

## B-7. MAJOR — Cancelled / unreadable scans leak orphan JPEGs forever

`ScanView.swift:142-162` saves the JPEG **before** OCR; every exit that does not
end in a saved receipt strands the file: OCR returns no lines
(`ScanView.swift:153-157`), or the user taps "Huỷ, không lưu" in Review
(`ReceiptViews.swift:522` → `onDone()` at `ScanView.swift:134-136`, which only
sets `draft = nil`). Nothing in the codebase ever deletes an unreferenced file
(grep: `ImageStore.delete` has exactly one call site, the detail-view delete).
Cancelled receipts — the most sensitive images, the ones the user chose **not**
to keep — accumulate indefinitely in `Documents/ReceiptImages`, invisible to the
UI and undeletable from inside the app.

Exact fix: `ScanDraft`'s cancellation path must clean up:

```swift
.sheet(item: $draft) { d in
    ReviewView(draft: d, onSaved: { draft = nil },
               onCancel: { ImageStore.delete(fileName: d.imageFileName); draft = nil })
}
```

…and in `process(image:)`, delete `fileName` in the `lines.isEmpty` branch.

## B-8. MINOR — Startup framework contact: passes TEAM.md #1 in substance, two residues

What is **right**: `@main` (`SoHoaDonApp.swift:9-15`) does nothing but attach a
local SwiftData container — no CloudKit, no `CKContainer`, no entitlements
anywhere (grep confirms zero hits). `LAContext` is created inside a view's
`onAppear` handler (`ContentView.swift:23,55-57`), not in the app struct or a
view's stored properties, and `canEvaluatePolicy` failure is genuinely fail-open
(`ContentView.swift:60-65`). This is not the Test-0 trap.

Residues:
1. `authenticateIfNeeded()` has no "evaluation in flight" guard. The manual
   button (`ContentView.swift:48`) can start a second `evaluatePolicy` on a
   second `LAContext` while the system prompt from the first is still up; the
   loser typically completes with failure and overwrites `lockNote` with the
   "try again" text under a live prompt. Add `private var isAuthenticating = false`
   (as `@State`), set/clear it around the call, early-return when set.
2. `.modelContainer(for:)` at `SoHoaDonApp.swift:14` uses the default
   configuration: if the on-disk store ever fails to load (corruption, a future
   schema change without a migration plan), SwiftData traps at launch with no
   fallback and no user-visible explanation. Acceptable for a v1 first install;
   it must be a conscious, recorded decision before any model change ships.

## B-9. MINOR — The fail-open lock note is computed, passed, and never displayed

`ContentView.swift:62` writes `lockNote` for the no-biometrics case and passes it
to `TabShellView(lockNote:)` (`ContentView.swift:18`); `TabShellView` stores it
(`ContentView.swift:83`) and **never renders it** — its body
(`ContentView.swift:88-111`) is only the `TabView`. The promised "mở kèm thông
báo" (BUILD1-NOTES.md, ContentView row) does not happen: the user is never told
the app is running unlocked. Fix: show the note once in `TabShellView` (e.g. a
dismissible banner/`alert` driven by `lockNote != nil`), or drop the parameter
and the claim.

## B-10. MINOR — Vision/OCR error is discarded; the completion can report "no text" for three different failures

`ScanView.swift:181` — `VNRecognizeTextRequest { req, _ in … }` ignores the
`Error?` parameter entirely, and `ScanView.swift:197-202` converts a thrown
`handler.perform` into the same `completion([])`. Combined with B-4's `cgImage`
nil path, "image unreadable," "Vision failed," and "genuinely blank page" all
surface to the user as one identical message, with nothing logged anywhere in
the app (there is not a single `os.Logger`/`print` in Build 1). TEAM.md #4:
evidence first. At minimum, propagate the error string into `errorText`.

**Checked and cleared in this class** (so the leader does not re-flag them):
no `as!`, no `try!`, no force-cast anywhere; the only force unwrap in the app is
`Models.swift:190` (`cardBrand!`), guarded on L190's own condition
(`cardBrand?.isEmpty == false`) — safe today, brittle if edited (MINOR style note,
prefer `if let`). All `m[i]`/`parts[i]` subscripts in `Parser.swift`/`Models.swift`
are guarded by the regex group counts or explicit `count` checks on the same
expression (e.g. `Parser.swift:144,174,262-264`, `Models.swift:218-222`).
Vision's completion is consumed through `DispatchQueue.main.async`
(`ScanView.swift:150-151`) before any `@State` is touched, and `modelContext`
is only used on the main (view) context in every view file — no off-queue
SwiftData use found. All public APIs used exist at iOS 17: SwiftData
`@Model/@Query/FetchDescriptor/.modelContainer` (17), `VNDocumentCameraViewController`
+ classic delegate (13), `VNRecognizeTextRequest` (13), `PhotosPicker`/
`loadTransferable` (16), `LAContext.deviceOwnerAuthentication`, two-parameter
`onChange(of:)` (17), `LabeledContent` (16), `TextField(axis:)` (16). No iOS 18/26
API (no `RecognizeDocumentsRequest`, no Liquid Glass) is referenced.
`BUILD1-NOTES` compile-flag #1 resolves in the code's favour: the closure
parameter is the base `VNRequest`, whose `results` is `[VNObservation]?`, so
`ScanView.swift:182-183` (`req.results ?? []` → `compactMap { $0 as? VNRecognizedTextObservation }`)
is type-correct as written.

---

# C. FINDINGS — LOGIC DEVIATIONS FROM BLUEPRINT / VENDOR-FORMATS (ordered by severity)

## C-1. MAJOR — The "Duyệt" button promotes any receipt to official, unconditionally

`ReceiptViews.swift:334-345`:

```swift
if receipt.status == .needsReview {
    Button {
        receipt.status = .reviewed
        try? modelContext.save()
    } label: { Label("Duyệt — đã kiểm, cho vào sổ chính thức", …) }
```

No check of `receiptFlags(receipt)` — the helper that already computes exactly
the disqualifying conditions (`ReceiptViews.swift:29-52`: missing total, unknown
classification, business without purpose). A receipt with **no total at all and
no classification** becomes a "chứng từ chính thức" in one tap. This defeats the
needsReview discipline at the exact gate that is supposed to enforce it
(BLUEPRINT/BUILD1-NOTES: unreviewed ≠ official).

Exact fix:

```swift
Button {
    receipt.status = .reviewed
    try? modelContext.save()
} label: { … }
.disabled(!receiptFlags(receipt).isEmpty)
```

(plus helper text listing why it cannot be approved yet).

## C-2. MAJOR — Home, Reports, and List totals count `needsReview` receipts as if they were official

- `HomeView.swift:9-20` — `yearSum(_:)` filters by classification and year only.
- `HomeView.swift:146-164` (`ReportsView.sum`) — same.
- `ReceiptViews.swift:142-168` — the list's running total, same.

Nothing anywhere sums reviewed-only money. The year tiles on the home screen —
the numbers the user will quote — silently include every unreviewed, possibly
mis-read receipt; Reports discloses only the *count* of pending receipts
(`HomeView.swift` Reports section, "…tờ đang chờ duyệt") while still folding
their money into the totals. Law: unreviewed ≠ official.

Exact fix: add a status predicate to every total, or present two clearly
labelled figures:

```swift
private func yearSum(_ kind: Classification) -> Int {
    currentYearReceipts
        .filter { $0.classification == kind && $0.status == .reviewed }
        .reduce(0) { $0 + ($1.totalCents ?? 0) }
}
```

## C-3. MAJOR — Cross-checks are computed once, at parse time, and never re-run on the values the user actually saves

`Parser.swift:387-420` (`validate`) runs only inside `ReceiptParser.parse`
(`Parser.swift:84`). `ReviewView.save` (`ReceiptViews.swift:577-602`) then
decides official status from the **original parse's** `draft.result.warnings`
(L600) — not from the edited `vendorText/subtotalText/taxText/totalText` fields
sitting in the same view. Both directions break:

1. **False official:** user edits the total in Review to a figure that contradicts
   subtotal+tax → no new warning exists → saved as `.reviewed`.
2. **False pending:** user hand-corrects *every* field perfectly → the original
   OCR warnings still force `.needsReview`, so a fully-verified receipt cannot
   become official in Review and must be rescued through the Detail screen —
   whose Duyệt button (C-1) checks nothing at all. The strict gate and the lax
   gate are on the wrong doors.

Exact fix — re-validate the edited values at the top of `save`:

```swift
var edited = draft.result
edited.subtotalCents = dollarsTextToCents(subtotalText)
edited.taxCents      = dollarsTextToCents(taxText)   // ParseResult stores taxes as a list; adapt accordingly
edited.totalCents    = dollarsTextToCents(totalText)
edited.date          = dateValue
let freshWarnings = ReceiptParser.validate(edited)   // requires validate to be internal, not private
let stillNeedsReview = selectedKind == .unknown || edited.totalCents == nil
    || !freshWarnings.isEmpty
    || (selectedKind == .business && purposeText.trimmingCharacters(in: .whitespaces).isEmpty)
```

(`validate` is currently `private static` at `Parser.swift:387`; widen it.)

## C-4. MAJOR — Global law 2 broken in construction: card last-4 and card brand are harvested from *different, unrelated lines*, and no payment-line context is required

`Parser.swift:295-328` (`findCard`): the first masked-looking match **anywhere**
in the document wins the last-4 (L297-311); the brand is then taken from the
first line anywhere that mentions a brand name (L316-327), whether or not it is
the payment line, or even the same slip (guest check + card slip in one photo).
Consequences:

- An "We accept VISA / MASTERCARD" header line, a brand printed in an ad, or the
  *other* slip's tender line supplies the brand for a last-4 it has nothing to
  do with. `suggestClassification` then presents "Thẻ Visa •• 2586" as a single
  read fact, and that pair is persisted as the receipt's snapshot
  (`ReceiptViews.swift:584-585`).
- The mask patterns themselves (`\*{3,}`, `X{3,}` under a case-insensitive regex,
  `Parser.swift:303-310`) are unanchored substrings: any `XXX…1234`-shaped token
  — a masked member/loyalty number, a redacted survey code — qualifies, with no
  requirement that the line look like a payment line (no tender/card/debit/
  approval context check).
- Credit where due: the specific Home Depot footer trap in VENDOR-FORMATS
  (bare 4 digits at the end of a footer code) does **not** fire, because bare
  digits never match — a mask is genuinely required. The law is half-kept.

Exact fix — require mask and brand/context on the *same* line first, fall back
to mask-only with `brand = nil`:

```swift
private static func findCard(lines: [OCRLine]) -> (last4: String?, brand: String?) {
    let paymentHint = ["CARD", "DEBIT", "CREDIT", "VISA", "MASTERCARD", "AMEX", "DISCOVER", "AUTH", "TENDER"]
    var maskedOnly: String? = nil
    for line in lines {
        guard let last4 = maskedLast4(in: line.text) else { continue }   // the three existing patterns, factored out
        let upper = line.text.uppercased()
        if paymentHint.contains(where: { upper.contains($0) }) {
            return (last4, brand(inLine: upper))                          // same-line brand, possibly nil
        }
        if maskedOnly == nil { maskedOnly = last4 }
    }
    return (maskedOnly, nil)   // brand only ever from the payment line itself
}
```

## C-5. MAJOR — Exclusion "zones" are single lines, not zones; the Suggested-Tip latch never releases; date/card extraction ignores zones entirely

`Parser.swift:240-276` (generic totals loop):

```swift
var ignoreTotals = false
for line in lines {
    if upper.contains("SUGGESTED TIP") || upper.contains("TIP GUIDE") { ignoreTotals = true }
    if upper.contains("RETURN POLICY") || upper.contains("MAX REFUND VALUE") { continue }
    …
}
```

- `RETURN POLICY` / `MAX REFUND VALUE` skip **only the header line itself**; the
  10–20 footer lines that follow it — the block VENDOR-FORMATS says contains
  fake dates and numbers on Home Depot receipts — are parsed normally for
  subtotal, tax, and totals on the very next iterations.
- `ignoreTotals`, once set by a tip guide, stays set for the rest of the
  receipt: a receipt whose real `TOTAL` line is printed *after* its tip guide
  yields no total at all (fail-safe — it lands in needsReview — but it is a
  needless manual-entry burden, and the inverse layout assumption is nowhere
  verified).
- The zone logic exists only in this one loop. `findDateTime`/`findDateOnly`
  (`Parser.swift:333-370`) and `findCard` (L295) scan the raw, un-zoned line
  list, so a Home Depot return-policy footer date-time is fully eligible to
  become the receipt's date (see also C-14).

Exact fix — make exclusion a pre-pass over the line list, shared by every extractor:

```swift
private static func applyingExclusionZones(to lines: [OCRLine]) -> [OCRLine] {
    var out: [OCRLine] = []
    var inExcludedZone = false
    for line in lines {
        let upper = line.text.uppercased()
        if upper.contains("RETURN POLICY") || upper.contains("SUGGESTED TIP") || upper.contains("TIP GUIDE") {
            inExcludedZone = true
        }
        // Zones on these receipts run to the end of the paper; if a future format
        // resumes content, end the zone on a recognised totals/payment header.
        if upper.hasPrefix("TOTAL") || upper.hasPrefix("SUBTOTAL") { inExcludedZone = false }
        if !inExcludedZone && !upper.contains("MAX REFUND VALUE") { out.append(line) }
    }
    return out
}
```

…and run date, card, subtotal, tax, and total extraction over the filtered list
(tip-zone lines may still be used for the *date*, never for money — encode that
choice explicitly if wanted, but choose it, don't inherit it by accident).

## C-6. MAJOR — TC# dedupe: weak/incorrect keys for most vendors, an alert that lies about the key type, and a dead `ignoreDuplicate` parameter

`Parser.swift:269-289`, `ReceiptViews.swift:529-533,560-577`:

1. Generic receipts get no vendor key at all — only the fallback
   `GEN|vendor|yyyy-MM-dd|total` (L283-289). VENDOR-FORMATS specifies real keys
   this code never extracts: Amazon **Order ID**, Lowe's **SALES#+TRANS#**,
   Love's **Ticket#**, restaurant **Check#**, Costco fallback **MBR#+Trn#**,
   Home Depot store/register/transaction. A Sam's receipt whose header OCR drops
   "Sam's Club" falls into the generic path, where its TC# is keyed `TC-…`
   (`Parser.swift:269-273`) instead of `SAMS-TC-…` (`Parser.swift:196-201` of the
   Sam's branch) — the *same physical receipt* scanned twice, read two ways,
   produces two different keys and no duplicate alert.
2. The fallback key **false-positives** legitimate repeats: two identical
   same-day purchases at the same vendor for the same total (two identical
   fuel stops, two identical coffee orders) are presented as duplicates.
3. Worse, the alert text hard-codes the explanation: "…khớp N hoá đơn đã lưu
   (cùng mã TC#)" (`ReceiptViews.swift:533`) even when the match was on the
   `GEN|…` fallback — the user is told a TC# matched when none exists.
4. `save(ignoreDuplicate:)` (`ReceiptViews.swift:577`) never reads its
   parameter; "Vẫn lưu thêm" and a clean save run identical code. Harmless
   today, and proof the duplicate path was not exercised end-to-end.
5. The stored `GEN|…` key is built from the **parsed** date/total
   (`Parser.swift:283-289`), but Review stores `dedupeKey = draft.result.dedupeKey`
   verbatim (`ReceiptViews.swift:590`) while storing the **edited** date/total —
   so after the user corrects an OCR error, the key no longer describes the
   receipt it is attached to, and a correct re-scan won't match it.

Exact fix: build the key at save time from the final stored fields, name the
key type honestly in the alert, and implement at least Order ID / Ticket# /
SALES#+TRANS# extraction in the generic branch; delete or honour
`ignoreDuplicate`.

## C-7. MAJOR — Detail-view classification edits keep the old kind's category and can leave an official receipt in a disqualified state

`ReceiptViews.swift:368-378` (`saveChanges`) + `ReceiptViews.swift:238-244`
(`categoryOptions` appends the stale category so it remains selectable):

```swift
receipt.classification = selectedKind
if kindChanged { receipt.classificationReason = "Anh đổi tay trong chi tiết hoá đơn" }
receipt.category = selectedCategory          // still e.g. "Đi Chợ" after switching to Business
receipt.businessPurpose = purposeText
try? modelContext.save(); savedNote = true   // status untouched
```

Switching Personal → Business leaves a personal category on a business receipt
(the tax report groups by that string, `HomeView.swift:166-179`), and if the
receipt was `.reviewed`, it **stays** `.reviewed` even when the edit leaves it
unknown-classified or business-without-purpose — the states Review is forbidden
from producing (compare `ReceiptViews.swift:598-602`).

Exact fix: on kind change, reset the category to the new kind's default unless
the current one belongs to the new kind, and re-derive the status:

```swift
if kindChanged && !Categories.list(for: selectedKind).contains(selectedCategory) {
    selectedCategory = Categories.defaultValue(for: selectedKind)
}
…
if selectedKind == .unknown || receipt.totalCents == nil
    || (selectedKind == .business && purposeText.trimmingCharacters(in: .whitespaces).isEmpty) {
    receipt.status = .needsReview
}
```

## C-8. MAJOR — Card-kind reclassification rewrites *all* receipts for that tail, including reviewed and hand-classified ones, with no category/status repair

`CardsView.swift:156-169` (quoted in full under Fix iii). The user consented to
"reclassify old receipts," so rewriting is not *silent* — but the blast radius
is larger than the dialog describes ("hoá đơn cũ của thẻ này"):

- Receipts the user had **manually** re-classified in the detail view precisely
  because that purchase was an exception (a personal buy on the business card)
  are flipped back — the per-receipt snapshot, BLUEPRINT §5's protection, is
  overwritten by the card edit after all.
- Receipts already `.reviewed` stay `.reviewed` under the new kind, even if
  they are now Business receipts with no business purpose and a Personal
  category (same defect family as C-7).
- `classificationReason` is overwritten on every match, erasing the original
  audit trail of why each receipt was classified.

Exact fix: restrict the sweep to receipts whose classification is still the
card-derived snapshot (e.g. reason prefix "Thẻ ••"), skip or separately list
manually-changed/reviewed ones, and after rewriting each receipt re-run the
C-7 status/category repair.

## C-9. MAJOR — Restaurant law not implemented at all: no `totalPrinted` / `tipAmount`, so the amount of record is the pre-tip printed total

VENDOR-FORMATS (restaurant row + global law 1): printed total excludes the
handwritten tip; the app must store `totalPrinted` and `tipAmount` separately
for user confirmation. Build 1 has neither field — `Receipt`
(`Models.swift:95-127`) has a single `totalCents`, `Parser` has no tip
extraction, and Review (`ReceiptViews.swift:443-472`) has no tip field. Every
restaurant receipt will be filed at the printed total, understating the actual
charge, with no prompt that a tip even might exist. The Suggested-Tip fake-total
exclusion (the half that *is* implemented) makes this easy to miss: the app is
protected against the wrong total, but never asks for the right one.
Fix: add `tipCents: Int?` to `Receipt`, a tip field in Review shown when the
receipt looks like a restaurant/guest-check, and make the cross-check
`subtotal + tax + tip ≈ total` once a tip is entered; totals in Home/Reports
should use printed+confirmed tip and say so.

## C-10. MAJOR — Generic totals: first `TOTAL` wins and `GRAND TOTAL` never matches — the Amazon rule is inverted/absent

`Parser.swift:262-268`: the pattern is anchored `^(TOTAL|TOTAL DUE|AMOUNT DUE|BALANCE DUE)…`
and guarded by `r.totalCents == nil`, so (a) the **first** total-shaped line is
final, and (b) a line beginning "GRAND TOTAL" — Amazon's per-package and
order-level wording — cannot match at all. VENDOR-FORMATS (Amazon row): one
order has many "Grand Total"s; the record takes the **order grand total at the
end**. As written, a multi-package Amazon printout yields either no total
(→ needsReview, fail-safe) or an early package total filed as the order total
if any plain "TOTAL" line precedes it (→ wrong number, and if subtotal+tax
happen to agree, **no flag** — the one silent-wrong case the cross-check
system exists to prevent; receipts *without* a captured subtotal get no
cross-check at all, `Parser.swift:401-405`).
Fix: collect all total candidates; prefer the last `GRAND TOTAL`; never let a
candidate win silently when several distinct candidates exist — flag it.

## C-11. MAJOR — Confidence discipline applies to the total only; vendor and date confidences are stored and never enforced

BLUEPRINT §6: ≥85% accept, 60–85% yellow, <60% forced confirmation — per field.
`Parser.validate` (`Parser.swift:412-418`) thresholds only `totalConfidence`.
`vendorConfidence`/`dateConfidence` are parsed, stored
(`ReceiptViews.swift:591-593`), and then never read again; Review's save rule
(`ReceiptViews.swift:598-602`) doesn't include an empty vendor either. A receipt
with vendor "" (Review field left blank — `ReceiptViews.swift:407` defaults a
nil vendor to "") and a guessed date saves as `.reviewed`, despite IRS proof
requiring amount **and date and place** (BLUEPRINT §4). Fix: in the C-3
re-validation, add
`vendorText.isEmpty || draft.result.vendorConfidence < 0.60 || draft.result.dateConfidence < 0.60`
to `stillNeedsReview` (using fresh confidences for user-edited fields is
impossible — treat a user-edited field as confirmed and clear its warning
explicitly, which is exactly the re-validation UX C-3 prescribes).

## C-12. MAJOR — Home "top categories" merges Personal and Business money under one category name

`HomeView.swift:22-34`:

```swift
var totals: [String: (Classification, Int)] = [:]
for receipt in currentYearReceipts {
    let key = receipt.category.isEmpty ? "Khác" : receipt.category
    let old = totals[key] ?? (receipt.classification, 0)
    totals[key] = (receipt.classification, old.1 + (receipt.totalCents ?? 0))
}
```

Grouping key is the category **name only**; the displayed kind is whichever
receipt happened to be processed for that name, while the total sums both
kinds. Any same-named category used for both kinds (the `unknown` category list
is literally `business + personal`, `Models.swift:79-84`, and detail edits can
carry a category across kinds — C-7) reports mixed money under a single
Personal *or* Business badge. `ReportsView` does this correctly with a
composite `classificationRaw|category` key (`HomeView.swift:166-172`) — Home
should copy that pattern.

## C-13. MINOR — Generic tax extraction: any line starting "TAX" is a tax line, valued at its last money token

`Parser.swift:257-260`: `upper.hasPrefix("TAX")` also matches `TAXABLE …`,
`TAX ID …`, `TAX EXEMPT …` lines, and `lastMoneyInLine` takes the last
`\d+\.\d{2}` on the line as the tax amount. A "TAXABLE AMOUNT 203.30" line
injects a $203.30 "tax" into `taxTotalCents`. Mitigated, not harmless: the
cross-check (`Parser.swift:401-405`) will usually fire and park the receipt in
needsReview, and Review shows one collapsed tax figure
(`ReceiptViews.swift:410` sums TAX 1 + TAX 2 into a single editable field,
discarding the per-rate split Sam's prints — acceptable for Build 1 totals,
but the split is lost from the record). Fix the prefix test to
`^TAX(ES)?\b`, `^SALES TAX\b`, or the Sam's-style `^TAX \d` shapes, and exclude
lines containing `TAXABLE`/`EXEMPT`/`ID`.

## C-14. MINOR — Date extraction: first date-*time* anywhere beats the transaction date; no validity check on the components

`Parser.swift:230-234` (generic): `findDateTime(in:) ?? findDateOnly(in:)` —
`findDateTime` scans the **entire** receipt first, so any later footer
date-time (Home Depot return-policy block, per VENDOR-FORMATS; survey/promo
blocks) outranks an earlier date-only transaction date. (Walmart is the
exception that wants its footer date — a per-vendor rule, not a global one.)
And `makeDate` (`Parser.swift:372-383`) validates only month 1–12 / day 1–31:
Feb 31, Apr 31, hour 25, minute 99 are all silently normalised by
`Calendar.date(from:)` into a different, plausible-looking date with the
*original line's* confidence attached. Dates feed the dedupe fallback key and
the tax year; a normalised date is a wrong date that no cross-check will ever
catch. Fix: validate `hour 0…23`, `minute 0…59`, and round-trip the components
(`Calendar.dateComponents` of the produced date must equal the inputs).

## C-15. MINOR — Sam's pending-item state machine can pair a quantity line with the wrong item

`Parser.swift:118-163`: `pending` survives across an intervening item that had
its own trailing amount (L147-153 appends that item but never clears/replaces
`pending`), and an `INST SV` line without an amount silently *replaces* a
pending regular item (L138). A following qty line then writes its
qty/unit/amount into the stale item (L119-126), and the replaced item is lost.
Real Sam's layout (qty line immediately follows its item) makes this rare, and
the `# ITEMS SOLD` cross-check (`Parser.swift:406-410`) will usually flag the
result — hence MINOR — but "usually flagged" is doing the work here. Fix: a
completed item line should flush or supersede `pending` explicitly, and the
`itemsSold` mismatch already guarantees this lands in needsReview via Review's
warnings rule.

## C-16. MINOR — Assorted snapshot/report/form defects (one line each)

- `HomeView.swift:174,226` — `ReportsView.categoryRows` strips the composite
  key back to the bare category name and uses it as the `ForEach` id; two rows
  (Personal + Business) sharing a display name collide as view identities.
  Use the composite key as `id`.
- `CardsView.swift:222-225` + `137-141` — editing a card whose stored kind is
  `.unknown` pre-selects `.personal` in the form; saving an otherwise
  no-change edit then triggers the kind-change confirmation dialog (and, on
  "reclassify," a real rewrite) for a change the user never made.
- `CardsView.swift:285-288` — the duplicate check for a new tail only tests
  **active** cards; re-adding an archived tail creates a second `CardTail`
  with the same `last4` (different kind possible). `suggestClassification`'s
  active-first rule (`Models.swift:183-186`) keeps suggestions sane, but the
  register now holds two contradictory records for one tail. Offer
  un-archive instead.
- `ReceiptViews.swift:225-231` (ReceiptDetailView `init`) — the stale-`@State`
  risk already disclosed as BUILD1-NOTES compile-flag #4 is still present and
  undisposed: if SwiftUI reuses the view for a different receipt, the pickers
  show the previous receipt's classification/category/purpose while
  `saveChanges` will write them into the new receipt. Fix with
  `.id(receipt.persistentModelID)` on the destination or `@Bindable`.
- `ReceiptViews.swift:147` + `HomeView.swift:39-60` — nested `NavigationStack`
  (ReceiptListView carries its own stack inside Home's) — disclosed in
  BUILD1-NOTES flag #5, still present; behaviour/aesthetic only.
- `Models.swift:211-228` — `dollarsTextToCents` mishandles negatives and
  truncates: `"-216.80"` → dollars `-216`, cents `+80` → **-21520**, not
  -21680; `"216.809"` silently truncates to 21680 instead of rounding or
  rejecting. Every money field the user types in Review passes through here
  (`ReceiptViews.swift:581-583`). Refund/return receipts are exactly the
  negative case. Fix by parsing the sign once, up front.
- `Models.swift:197-202` — `formatMoney` allocates a `NumberFormatter` on every
  call, including every list row; cache one static formatter. (Pairs with B-3
  for list smoothness.)

**Checked and cleared in this class:** the flag-never-rewrite law holds in the
parser — `validate` (`Parser.swift:387-420`) only appends warning strings and
never mutates amounts, dates, or the total; tolerances are ±2¢ for both
Σ-items-vs-subtotal and subtotal+tax-vs-total (`Parser.swift:397,402`), and the
stored-receipt recheck (`ReceiptViews.swift:29-52`) uses the same tolerance.
Sam's TC# key (`Parser.swift:196-201`: 16–24 digits, spaces stripped,
`SAMS-TC-` prefix), INST SV negative amounts, and the `# ITEMS SOLD` count
check are all present as specified. Card tails are archive-only — there is no
delete path for `CardTail` anywhere in `CardsView.swift` (only
archive/un-archive, `CardsView.swift:130-133`), and the default card-edit path
does **not** rewrite receipts (the dialog, C-8, is the only route). The Review
baseline needsReview rule (`ReceiptViews.swift:598-602`: unknown kind, missing
total, any parse warning, business without purpose) is correctly implemented
— its defects are the un-revalidated warnings (C-3) and the missing
vendor/confidence terms (C-11), not the rule itself.

---

# COMPILE CONFIDENCE STATEMENT

**I sign that this compiles — because it did. (Updated with field evidence,
2026-11-08 23:18 CST; this statement supersedes the first draft's.)**

The cloud build of Build 1 exactly as pushed (commit dba8693) **SUCCEEDED**
under Xcode 16 on the macOS-15 runner. Compile risk for the code as pushed is
therefore settled by evidence, not by my judgement: there are **no open
BLOCKER compile findings**. My first draft carried one potential compile
blocker (tuple key-paths in `ForEach`, old B-1); the successful build refutes
it, and §B-1 records that retraction honestly rather than quietly deleting it.
There should be — and are — no remaining compile findings: every other
uncertainty I examined while drafting resolved in the code's favour
(`VNRequest.results` typing, `ScanView.swift:182-183`, cleared in B-10; the
canonical `@Relationship` form, `Models.swift:126`; custom `init`s assigning
only some `@State` wrappers, the rest defaulted; two-parameter `onChange`;
all APIs at or below the iOS 17.0 / Swift 5.9 target in `project.yml`), and
the compiler has now confirmed that reading wholesale. The `project.yml`
INFOPLIST pairing I had marked UNVERIFIED is likewise settled in practice:
it built.

What remains uncertain is **behaviour, not compilation** — and the field test
moved the largest uncertainty from "unknown" to "proven failure": the OCR
pipeline loses every amount on a real Sam's Club digital receipt (§F). None
of the audit's open findings (F1–F3, B-2…B-10, C-1…C-16) is a compile risk;
they are runtime, data-loss, and logic findings, and the compiler could not
have caught any of them.

**Gate recommendation (per TEAM.md): Code signature WITHHELD — on behaviour,
not compilation.** Release must wait for: §F in Build-2 priority order —
(1) F1 PDF import with text-layer extraction, (2) F2 row-merge + split-line
tolerance + tall-image tiling, (3) F3 raw-text viewer — **and** the §F
acceptance test passing against the archived Sam's fixture (subtotal 203.30,
taxes 9.60 + 3.90, total 216.80, 10 line items, 15 items sold; fixture still
PENDING — the file has not yet arrived); plus B-2 (silent save failure) and
C-1/C-2/C-3 (the needsReview gate). Those are the difference between an app
that compiles — proven — and an app whose numbers can be trusted — not yet
proven.

---

## LEADER ADDENDUM — 2026-11-08 23:23 CST (fixture archived; §F updated)

The §F acceptance fixture has ARRIVED and is archived:
`samples/sample-002-sams-downloaded-receipt.jpg` (554×1457 px) +
`samples/sample-002-ground-truth.md` (visual-row transcription, arithmetic
hand-verified twice: items = 203.30; +9.60+3.90 = 216.80; qty = 15).
Every "fixture PENDING" note in §F and in the compile-confidence statement
above is superseded: read as FIXTURE ARCHIVED.

Leader verification (own trace): with row-merged lines, the CURRENT parser
rules reproduce the full result on this fixture — including the trap that an
INST SV line can be followed by its own qty line ("INST SV 12 OZ BOWL" ->
"2 AT 1 FOR 2.25- 4.50-T" -> -4.50 via the existing pending+qty path). The
defect is confined to the OCR line-formation layer (F2) and the missing PDF
door (F1); no parser-rule change is needed for this fixture beyond F2b
split-line tolerance.

Brand nuance (corrects a shorthand in the field report): findCard scans ALL
lines and takes the FIRST brand-bearing line, appending " Debit" only if
THAT line contains "DEBIT". The field output "Mastercard" (no Debit) is
fact; the exact OCR-side reason is UNVERIFIED (no raw OCR text — F3).
Fix candidate C-17 (MINOR, Tier 2): if the chosen brand line lacks DEBIT,
also scan the lines adjacent to the masked-card line / any TEND line.

Camera capture remains FIELD-UNVERIFIED (the user tested via PhotosPicker);
Build 2 acceptance must include one camera capture of this same receipt.
Full addendum: QA-VERDICT.md, "PHỤ LỤC — 23:23 CST".

---

## LEADER ADDENDUM #2 — 2026-11-08 23:24 CST (Field Test 2: crumpled Home Depot paper)

User verdict (verbatim): "Chất lượng scan dữ liệu rất tệ" / "Thua các app
chính thức rất nhiều" — accepted on the evidence. Fixture:
`samples/sample-003-ground-truth.md` (vendor The Home Depot; 03/03/2025
12:59 PM; 6.98+19.97+69.96 = 96.91; tax 8.25; TOTAL $105.16; Visa ••3830
unregistered — arithmetic re-verified by the leader).

Build 1 passed date/time, card, unregistered-card suggestion, missing-total
warning, needsReview discipline. It FAILED vendor and all amounts:
- **C-18 (MAJOR, new)** — `parseGeneric` vendor logic, `Parser.swift:219`
  scans only `lines.prefix(6)` for known vendors, `:229-231` falls back to
  the FIRST line (<=40 chars): the slogan "How doers get more done" became
  the vendor ("How doers"). Its recorded confidence (<=0.5) is enforced
  nowhere (see C-11). Fix: search ALL lines + fuzzy match for known
  vendors; a first-line/slogan fallback is forbidden without a
  low-confidence flag AND forced needsReview.
- **ENGINE EVALUATION is now the Build 2 centerpiece (supersedes a
  patch-only reading of F2):** (a) classic Vision + image preprocessing
  (receipt-bounds crop, perspective/straighten, contrast upscale) +
  row-merge; (b) iOS 26 `RecognizeDocumentsRequest` via a SEPARATE
  pipeline test build (Test-0-style isolation of the SDK/deployment
  change) on the user's iOS 27. Decision rule: higher score on the fixed
  sample set wins.
- **SCORECARD GATE (permanent):** samples 001/002/003 scored on vendor /
  date / total / items. Build 2 passes only if totals+dates are correct
  on all 3 AND no wrong number is ever presented unflagged. Build 1's
  scores and the full re-ordered Build 2 list: QA-VERDICT.md, Appendix B.
