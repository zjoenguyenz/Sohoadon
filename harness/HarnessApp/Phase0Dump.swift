import Foundation
import CoreGraphics

// MARK: - Phase 0 (CORE-OPTIMIZATION-PLAN §"Pha 0") — enriched stream dump
//
// MEASUREMENT ONLY. Nothing here feeds back into reading, candidate
// selection or scoring: these helpers only READ values the harness
// already holds (ReadOutcome, the per-candidate diagnostics records,
// the driver's CandidateEvaluation / CandidateScorer.score result) and
// turn them into JSON-safe dictionaries for dumpImageRun().
//
// Per-candidate fields are read via Mirror reflection on purpose: the
// candidate record type lives in ReadDiagnostics.swift (app source, not
// in this package), so the dump does not hard-code its property names.
// Whatever the record stores (scalars, a score breakdown, a
// ParseResult) is surfaced; whatever it does not store is reported as
// unavailable with an explicit "source" tag instead of being guessed.

let phase0DumpSchema = "phase0-v1"

/// Unwraps `Optional` values held in an `Any`; nil when `.none`.
func phase0Unwrap(_ value: Any) -> Any? {
    let m = Mirror(reflecting: value)
    if m.displayStyle == .optional {
        guard let inner = m.children.first?.value else { return nil }
        return phase0Unwrap(inner)
    }
    return value
}

/// JSON-safe number (JSONSerialization throws on NaN/inf) — same
/// mapping as boxDict(): NaN -> -999999, +/-inf -> +/-999999.
func phase0Finite(_ v: Double) -> Double {
    if v.isNaN { return -999999 }
    if v == .infinity { return 999999 }
    if v == -.infinity { return -999999 }
    return v
}

/// Converts a scalar to a JSON value; nil for non-scalars.
func phase0Scalar(_ value: Any, includeStrings: Bool) -> Any? {
    switch value {
    case let b as Bool: return b
    case let i as Int: return i
    case let i as Int32: return Int(i)
    case let i as Int64: return Int(i)
    case let d as Double: return phase0Finite(d)
    case let f as Float: return phase0Finite(Double(f))
    case let c as CGFloat: return phase0Finite(Double(c))
    case let s as String: return includeStrings ? s : nil
    default: return nil
    }
}

/// Flattens the scalar stored properties of `value` (structs/classes,
/// nested up to `maxDepth`) into "a.b" -> scalar. Optionals that are
/// nil become NSNull so the key still shows the field exists.
func phase0Flatten(_ value: Any, includeStrings: Bool,
                   maxDepth: Int = 2, prefix: String = "") -> [String: Any] {
    var out: [String: Any] = [:]
    var mirror: Mirror? = Mirror(reflecting: value)
    while let m = mirror {
        for child in m.children {
            guard let label = child.label else { continue }
            let key = prefix.isEmpty ? label : prefix + "." + label
            guard let v = phase0Unwrap(child.value) else {
                out[key] = NSNull()
                continue
            }
            if let s = phase0Scalar(v, includeStrings: includeStrings) {
                out[key] = s
                continue
            }
            let style = Mirror(reflecting: v).displayStyle
            if maxDepth > 0, style == .struct || style == .class {
                for (k, x) in phase0Flatten(v, includeStrings: includeStrings,
                                            maxDepth: maxDepth - 1, prefix: key) {
                    out[k] = x
                }
            }
        }
        mirror = m.superclassMirror
    }
    return out
}

/// Ledger closure of a ParseResult — the same E1/E2 equalities as the
/// driver's evaluate() (E1: Σitems == subtotal; E2: subtotal + tax
/// within 2c of total). Used only for candidates whose own ParseResult
/// is found in their diagnostics record; the winner uses run.e1/e2.
func phase0Ledger(_ p: ParseResult) -> (e1: Bool, e2: Bool) {
    var e1 = false
    if let subtotal = p.subtotalCents,
       let sum = SafeMoney.sumCents(p.items.map { $0.amountCents ?? 0 }) {
        e1 = sum == subtotal
    }
    var e2 = false
    if let subtotal = p.subtotalCents, let total = p.totalCents {
        let implied = SafeMoney.checkedAdd(subtotal, p.taxTotalCents)
        e2 = implied.map { abs($0 - total) <= 2 } ?? false
    }
    return (e1, e2)
}

/// Parse-outcome class used by stream_compare.py:
///   closed   — E1 and E2 both hold
///   all-nil  — no subtotal, no total and no tax line parsed
///   unclosed — anything else
func phase0OutcomeClass(_ p: ParseResult, e1: Bool, e2: Bool) -> String {
    if e1 && e2 { return "closed" }
    if p.subtotalCents == nil && p.totalCents == nil && p.taxes.isEmpty {
        return "all-nil"
    }
    return "unclosed"
}

/// Short structured parse summary (the string "parse" key is kept).
func phase0ParseSummary(_ p: ParseResult, e1: Bool, e2: Bool,
                        source: String) -> [String: Any] {
    let sum = SafeMoney.sumCents(p.items.map { $0.amountCents ?? 0 })
    return [
        "available": true,
        "source": source,
        "vendor": p.vendor.map { $0 as Any } ?? NSNull(),
        "subtotalCents": p.subtotalCents.map { $0 as Any } ?? NSNull(),
        "taxCents": p.taxTotalCents,
        "taxLines": p.taxes.count,
        "totalCents": p.totalCents.map { $0 as Any } ?? NSNull(),
        "itemCount": p.items.count,
        "itemsMissingAmount": p.items.filter { $0.amountCents == nil }.count,
        "sumItemsCents": sum.map { $0 as Any } ?? NSNull(),
        "e1": e1,
        "e2": e2,
        "closed": e1 && e2,
        "outcomeClass": phase0OutcomeClass(p, e1: e1, e2: e2),
    ]
}

/// Finds a ParseResult stored anywhere (depth <= 2) in a record.
func phase0FindParseResult(_ value: Any, depth: Int = 2) -> ParseResult? {
    var mirror: Mirror? = Mirror(reflecting: value)
    while let m = mirror {
        for child in m.children {
            guard let v = phase0Unwrap(child.value) else { continue }
            if let p = v as? ParseResult { return p }
            let style = Mirror(reflecting: v).displayStyle
            if depth > 0, style == .struct || style == .class,
               let p = phase0FindParseResult(v, depth: depth - 1) {
                return p
            }
        }
        mirror = m.superclassMirror
    }
    return nil
}

/// Finds a stored score breakdown in a candidate record: a child whose
/// dynamic type equals the CandidateScorer.score(...) result type, or
/// whose label names a breakdown/components field.
func phase0FindScoreBreakdown(_ record: Any, breakdownType: Any.Type?) -> Any? {
    let labelHints = ["component", "breakdown", "scoreparts", "scoredetail"]
    var mirror: Mirror? = Mirror(reflecting: record)
    while let m = mirror {
        for child in m.children {
            guard let v = phase0Unwrap(child.value) else { continue }
            let style = Mirror(reflecting: v).displayStyle
            guard style == .struct || style == .class || style == .dictionary else { continue }
            if let t = breakdownType, type(of: v) == t { return v }
            let label = (child.label ?? "").lowercased()
            if labelHints.contains(where: { label.contains($0) }) { return v }
        }
        mirror = m.superclassMirror
    }
    return nil
}

/// Numeric components of a breakdown value (struct/class or [String: number]).
func phase0Components(_ breakdown: Any) -> [String: Any] {
    if let dict = breakdown as? [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in dict {
            if let u = phase0Unwrap(v), let s = phase0Scalar(u, includeStrings: false) {
                out[k] = s
            }
        }
        return out
    }
    return phase0Flatten(breakdown, includeStrings: false)
}

/// Winner-side context the dump already holds (all read-only).
struct Phase0WinnerContext {
    var parsed: ParseResult
    var e1: Bool
    var e2: Bool
    var driverEvaluation: Any?
    var driverBreakdown: Any?
}

/// Additive keys for ONE candidate entry of the stream dump.
func phase0CandidateFields(record: Any, isWinner: Bool,
                           winner: Phase0WinnerContext) -> [String: Any] {
    var out: [String: Any] = [:]
    out["recordFields"] = phase0Flatten(record, includeStrings: true, maxDepth: 1)

    let breakdownType = winner.driverBreakdown.map { type(of: $0) }
    if let stored = phase0FindScoreBreakdown(record, breakdownType: breakdownType) {
        out["scoreComponents"] = phase0Components(stored)
        out["scoreComponentsSource"] = "candidateRecord"
    } else if isWinner, let b = winner.driverBreakdown {
        out["scoreComponents"] = phase0Components(b)
        out["scoreComponentsSource"] = "driverRescore"
    } else {
        out["scoreComponents"] = [String: Any]()
        out["scoreComponentsSource"] = "unavailable"
    }
    if isWinner, let ev = winner.driverEvaluation {
        out["scoreInputs"] = phase0Flatten(ev, includeStrings: false)
    }

    if let p = phase0FindParseResult(record) {
        let l = phase0Ledger(p)
        out["parseSummary"] = phase0ParseSummary(p, e1: l.e1, e2: l.e2,
                                                 source: "candidateRecord")
    } else if isWinner {
        out["parseSummary"] = phase0ParseSummary(winner.parsed, e1: winner.e1,
                                                 e2: winner.e2,
                                                 source: "readOutcome")
    } else {
        out["parseSummary"] = ["available": false, "source": "unavailable"] as [String: Any]
    }
    return out
}
