#!/usr/bin/env python3
"""Independent static verification of L-2026-11-13-21 (BusinessPurposeField)
in the live tree v3-phase4/app/ReceiptViews.swift vs staging v4-4/fix4.

Shift 2026-11-14 00:40 CST. This script was written and run by the on-duty
shift; it does NOT compile Swift and does NOT prove device behaviour.
Checks are file-level only, read directly from disk.
"""
import hashlib
import re
import sys
from pathlib import Path

BASE = Path.home() / "workspace/receipt-app"
LIVE = BASE / "v3-phase4/app/ReceiptViews.swift"
FIX4 = BASE / "v4-4/fix4/ReceiptViews.swift"
FIX3 = BASE / "v4-4/fix3/ReceiptViews.swift"
MODELS = BASE / "v3-phase4/app/Models.swift"

results = []

def check(name, ok, detail=""):
    results.append((name, ok, detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name}  {detail}")

live = LIVE.read_text(encoding="utf-8")
fix4 = FIX4.read_text(encoding="utf-8")
fix3 = FIX3.read_text(encoding="utf-8")
lines = live.splitlines()

# 1. Live tree is byte-identical to the fix4 staging file
h_live = hashlib.sha256(live.encode()).hexdigest()
h_fix4 = hashlib.sha256(fix4.encode()).hexdigest()
check("live == fix4 byte-identical", h_live == h_fix4, f"sha256={h_live[:16]}...")

# 2. Exactly one BusinessPurposeField definition
defs = [i + 1 for i, l in enumerate(lines) if "struct BusinessPurposeField: View" in l]
check("exactly 1 struct definition", len(defs) == 1, f"lines={defs}")

# 3. Exactly 3 usages (call sites), excluding the definition line
uses = [i + 1 for i, l in enumerate(lines)
        if "BusinessPurposeField(text: $purposeText)" in l]
check("exactly 3 call sites", len(uses) == 3, f"lines={uses}")

# 4. Options list equals the 5 preset strings in the code
m = re.search(r"static let options = \[(.*?)\]", live, re.S)
opts = re.findall(r'"([^"]+)"', m.group(1)) if m else []
expected = [
    "Mua cho khách trong tiệm",
    "Mua cho nhân viên trong tiệm",
    "Mua cho khách và nhân viên",
    "Dùng cho hoạt động của tiệm",
    "Mua nguyên liệu / hàng hoá cho tiệm",
]
check("options == 5 presets", opts == expected, f"found={opts}")

# 5. Picker scaffolding: empty placeholder tag + custom tag + custom TextField
check("placeholder tag '' present", 'Text("— Chọn mục đích —").tag("")' in live)
check("custom tag present", 'Text("Tự ghi…").tag("__custom__")' in live)
tf = [i + 1 for i, l in enumerate(lines) if 'TextField("Mục đích business (mua để làm gì)"' in l]
# the only remaining free-text field for purpose must sit inside the struct (def..def+52)
inside = defs and all(defs[0] <= n <= defs[0] + 52 for n in tf)
check("only 1 purpose TextField, inside struct (custom mode)", len(tf) == 1 and bool(inside),
      f"lines={tf}, struct_at={defs}")

# 6. All three save paths write purposeText into the record
writes = [i + 1 for i, l in enumerate(lines) if "receipt.businessPurpose = purposeText" in l]
check("exactly 3 writes receipt.businessPurpose = purposeText", len(writes) == 3,
      f"lines={writes}")

# 7. Flag wiring: constant, flag condition, self-serving flag area with its own save button
check("missingPurposeFlagText constant", 'let missingPurposeFlagText = "Thiếu mục đích business' in live)
flag_cond = "receipt.classification == .business && receipt.businessPurpose.trimmingCharacters(in: .whitespaces).isEmpty" in live
check("flag condition business+empty", flag_cond)
flag_block = re.search(r"if flag == missingPurposeFlagText \{\s*\n\s*BusinessPurposeField\(text: \$purposeText\)\s*\n\s*Button\(\"Lưu mục đích\"\) \{ saveChanges\(\) \}", live)
check("flag area: field + own 'Lưu mục đích' button", flag_block is not None)

# 8. fix3 -> fix4 diff scope: exactly 4 hunks (1 struct addition + 3 call-site swaps).
# NOTE: first run of this verifier expected 3 and FAILed — that was the verifier's
# own miscount (it forgot the struct-addition hunk); the code was not at fault.
import difflib
diff = list(difflib.unified_diff(fix3.splitlines(), fix4.splitlines(), lineterm=""))
hunks = [l for l in diff if l.startswith("@@")]
check("fix3->fix4 diff hunks == 4 (1 add + 3 swaps)", len(hunks) == 4, f"hunks={len(hunks)}")
removed_tf = [l for l in diff if l.startswith("-") and 'TextField("Mục đích business' in l]
added_bpf = [l for l in diff if l.startswith("+") and "BusinessPurposeField(text: $purposeText)" in l]
check("diff swaps 3 TextField -> 3 BusinessPurposeField", len(removed_tf) == 3 and len(added_bpf) == 3,
      f"removed={len(removed_tf)} added={len(added_bpf)}")

# 9. Brace balance on string/comment-stripped source
def strip_code(src):
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == '"':
            # naive string skip (handles escapes; Swift multiline strings not present in this file's purpose area)
            i += 1
            while i < n and src[i] != '"':
                if src[i] == "\\":
                    i += 1
                i += 1
            i += 1
        elif c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
        else:
            out.append(c)
            i += 1
    return "".join(out)

stripped = strip_code(live)
check("brace balance {} == 0 net", stripped.count("{") == stripped.count("}"),
      f"open={stripped.count('{')} close={stripped.count('}')}")
check("paren balance () == 0 net", stripped.count("(") == stripped.count(")"),
      f"open={stripped.count('(')} close={stripped.count(')')}")

# 10. Model untouched by L-21: businessPurpose still a plain String on Receipt
models = MODELS.read_text(encoding="utf-8")
check("Models.swift: businessPurpose is String var",
      re.search(r"var businessPurpose:\s*String", models) is not None)

failed = [r for r in results if not r[1]]
print(f"\nTOTAL: {len(results) - len(failed)}/{len(results)} PASS")
sys.exit(1 if failed else 0)
