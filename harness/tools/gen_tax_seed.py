#!/usr/bin/env python3
"""Sinh TaxSeed.swift cho GL-Keeper Pha 2 từ ok-tax.json (bảng thuế
Oklahoma của Devin, đã được leader kiểm chứng 2026-11-21 — xem
study/OKLAHOMA-TAX-NOTES.md).

Nguồn:  devin-received-2026-11-21/ok-tax.json (schema ok-tax/1,
        hiệu lực 2026-10-01 → 2027-03-31, OTC "Rates and Codes").
Đích:   v3-phase4/app/TaxSeed.swift — KHÔNG sửa tay file đích;
        muốn đổi bảng thì sửa ok-tax.json rồi chạy lại script này.

Luật sinh:
- Mỗi (area × county portion) thành một TaxAreaPortion; ba phần %
  lấy từ split{state,county,city} của chính portion.
- zipPortionIDs: theo zip_index.zips — ứng viên ĐẦU TIÊN (nhiều
  địa chỉ nhất) của mỗi ZIP thắng.
- Tự kiểm: full = state+county+city khớp full_rate và grocery =
  county+city khớp grocery_rate của nguồn (sai lệch > 0.01 → dừng);
  ba giá trị đã kiểm chứng độc lập trong OKLAHOMA-TAX-NOTES.md.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "devin-received-2026-11-21" / "ok-tax.json"
DST = ROOT / "v3-phase4" / "app" / "TaxSeed.swift"


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def portion_id(area: str, county: str) -> str:
    county_short = county.replace(" County", "")
    return f"{slug(area)}-{slug(county_short)}"


def main() -> int:
    data = json.loads(SRC.read_text())
    assert data["schema"] == "ok-tax/1", data["schema"]

    portions = []
    by_key = {}
    for area in data["areas"]:
        for p in area["portions"]:
            pid = portion_id(area["name"], p["county"])
            split = p["split"]
            full = split["state"] + split["county"] + split["city"]
            grocery = split["county"] + split["city"]
            if abs(full - p["full_rate"]) > 0.01 or abs(grocery - p["grocery_rate"]) > 0.01:
                print(f"SPLIT KHÔNG KHỚP: {pid} full {full} vs {p['full_rate']}, "
                      f"grocery {grocery} vs {p['grocery_rate']}")
                return 1
            portions.append({
                "id": pid,
                "area": area["name"],
                "county": p["county"],
                "state": split["state"],
                "county_pct": split["county"],
                "city": split["city"],
                "zips": p["zips"],
            })
            by_key[(area["name"], p["county"])] = pid

    zip_map = {}
    for zip_code, candidates in data["zip_index"]["zips"].items():
        first = candidates[0]
        zip_map[zip_code] = by_key[(first["area"], first["county"])]

    # Giá trị đã kiểm chứng độc lập (OKLAHOMA-TAX-NOTES.md).
    checks = {
        "tulsa-tulsa": (8.517, 4.017),
        "broken-arrow-tulsa": (8.417, 3.917),
        "sand-springs-tulsa": (8.917, 4.417),
        "glenpool-tulsa": (9.967, 5.467),
    }
    for p in portions:
        if p["id"] in checks:
            full = p["state"] + p["county_pct"] + p["city"]
            grocery = p["county_pct"] + p["city"]
            ef, eg = checks[p["id"]]
            assert abs(full - ef) < 0.01 and abs(grocery - eg) < 0.01, p["id"]
    assert zip_map["74133"] == "tulsa-tulsa"
    assert zip_map["74063"] == "sand-springs-tulsa"
    assert zip_map["74014"] == "broken-arrow-wagoner"

    def num(x: float) -> str:
        return f"{x:.3f}".rstrip("0").rstrip(".") if x != int(x) else f"{x:.1f}"

    lines = []
    lines.append("// TaxSeed.swift — BẢNG THUẾ HẠT GIỐNG (SINH TỰ ĐỘNG)")
    lines.append("// Nguồn: ok-tax.json (Devin, từ OTC \"Rates and Codes\",")
    lines.append("// hiệu lực 2026-10-01 → 2027-03-31) — đã kiểm chứng trong")
    lines.append("// study/OKLAHOMA-TAX-NOTES.md. Sinh bởi")
    lines.append("// harness/tools/gen_tax_seed.py — KHÔNG sửa tay file này;")
    lines.append("// sửa ok-tax.json rồi chạy lại script.")
    lines.append("// Pha 2 (L-2026-11-21-47): cơ chế hạ cánh bằng thuế.")
    lines.append("")
    lines.append("extension TaxTable {")
    lines.append("    /// Bảng hạt giống đóng gói trong app (vùng Tulsa metro).")
    lines.append("    static let seed = TaxTable(")
    lines.append("        portions: [")
    for p in portions:
        zips = ", ".join(f'"{z}"' for z in p["zips"])
        lines.append(
            f'            TaxAreaPortion(id: "{p["id"]}", '
            f'areaName: "{p["area"]}", countyName: "{p["county"]}", '
            f'statePct: {num(p["state"])}, countyPct: {num(p["county_pct"])}, '
            f'cityPct: {num(p["city"])}, zips: [{zips}]),')
    lines.append("        ],")
    lines.append("        zipPortionIDs: [")
    for zip_code in sorted(zip_map):
        lines.append(f'            "{zip_code}": "{zip_map[zip_code]}",')
    lines.append("        ])")
    lines.append("}")
    lines.append("")
    DST.write_text("\n".join(lines))
    print(f"OK: {len(portions)} portions, {len(zip_map)} ZIP → {DST}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
