#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
VERIFIER ĐỘC LẬP cho cổng G2 — không dùng lại biến đổi trong bộ nhớ:
  1) Đọc flows/Tnn.txt TỪ ĐĨA, chạy lại evaluate() của runner -> verdict
     phải khớp từng ca với bảng text-degrade-results.txt đã lưu.
  2) Luồng đóng băng phải KHỚP SHA của lần chạy runner (chạy runner lại
     trong tiến trình con và so flows trước/sau: byte-trùng = tái lập được).
  3) Trừ 2 ca đối chứng, mọi flow phải KHÁC luồng gốc của nó; 2 ca đối
     chứng phải TRÙNG luồng gốc.
  4) Đủ 6 họ bệnh §3.3 (SPLIT/DROP/NOISE/BEFORE/DUP/ GARB) + CTRL.
Chạy: python3 bench-prep/text-degrade/verify_text_degrade.py
"""
import hashlib
import pathlib
import re
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import run_text_degrade as runner  # noqa: E402


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    fails = []
    # (2) tái lập: hash flows trước -> chạy runner -> hash sau
    before = {p.name: sha(p) for p in sorted((HERE / "flows").glob("*.txt"))}
    subprocess.run([sys.executable, str(HERE / "run_text_degrade.py")],
                   capture_output=True, text=True)
    after = {p.name: sha(p) for p in sorted((HERE / "flows").glob("*.txt"))}
    if before != after:
        fails.append("flows không tái lập byte-trùng khi chạy lại runner")
    print(f"{'PASS' if before == after else 'FAIL'} tai lap flows: "
          f"{len(after)} file byte-trung sau khi chay lai runner")

    # (1) verdict từ đĩa vs bảng đã lưu
    results = (HERE / "text-degrade-results.txt").read_text(encoding="utf-8")
    table = {}
    for line in results.splitlines():
        m = re.match(r"^(T\d\d)\s+(\S+)\s+(\d{3})\s+(CORRECT-REPAIRED|CORRECT|FLAGGED|SILENT-WRONG)\b", line)
        if m:
            table[m.group(1)] = (m.group(2), m.group(3), m.group(4))
    ok_cases = 0
    fam_seen = set()
    for code, fam, src, desc, _fn in runner.CASES:
        fam_seen.add(fam)
        flow = (HERE / "flows" / f"{code}.txt").read_text(encoding="utf-8")
        lines = [(t, runner.CONF) for t in flow.splitlines() if t.strip()]
        ev = runner.evaluate(src, lines)
        want = table.get(code)
        good = want is not None and want[2] == ev["verdict"] and want[0] == fam and want[1] == src
        ok_cases += 1 if good else 0
        if not good:
            fails.append(f"{code}: verdict tu dia {ev['verdict']} != bang {want}")
        # (3) khác/trùng gốc
        base = runner.base_lines(src)
        same = [t for t, _ in lines] == [t for t, _ in base]
        if fam == "CTRL" and not same:
            fails.append(f"{code}: ca doi chung khong trung luong goc")
        if fam != "CTRL" and same:
            fails.append(f"{code}: flow suy bien trung luong goc (bien doi khong tac dung)")
    print(f"{'PASS' if ok_cases == len(runner.CASES) else 'FAIL'} verdict tu dia khop bang: "
          f"{ok_cases}/{len(runner.CASES)} ca")

    # (4) đủ họ
    need = {"SPLIT", "DROP", "NOISE", "BEFORE", "DUP", "GARB", "CTRL"}
    missing = need - fam_seen
    if missing:
        fails.append(f"thieu ho benh: {sorted(missing)}")
    print(f"{'PASS' if not missing else 'FAIL'} du 6 ho benh §3.3 + CTRL: {sorted(fam_seen)}")

    print("== VERIFY G2:", "PASS" if not fails else "FAIL", "==")
    for f in fails:
        print("  FAIL:", f)
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
