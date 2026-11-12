#!/usr/bin/env python3
"""CRASH-AUDIT stress (ca 2026-11-11 20:40): chạy BẢN GƯƠNG Python của
integrate-v2/Parser.swift (port_swift_mirror.py, tem core-v2-1) trên:
  (a) toàn bộ 132 file dòng-cuối buổi đo (bench-prep/session-lines/),
  (b) các đột biến xác định (seed cố định) của từng file: xáo trộn,
      cắt nửa, nhân ba, đảo ngược, chèn ký tự rác vào token tiền,
  (c) ca biên chế tay: rỗng, 1 dòng, token tiền khổng lồ, 5000 dòng lặp.
Mục tiêu: săn NGOẠI LỆ (IndexError/ValueError/RecursionError...) và
THỜI GIAN chạy bất thường (proxy rủi ro watchdog) ở tầng logic parser.
GIỚI HẠN TRUNG THỰC: gương Python không tái hiện được trap của Swift
(tràn Int, ép kiểu) — các nguy cơ đó kết luận bằng ĐỌC CODE riêng
trong CRASH-AUDIT-LEDGER.md, không bằng script này.
"""
import importlib.util
import pathlib
import random
import sys
import time
import traceback

ROOT = pathlib.Path(__file__).resolve().parents[2]


def load(name, path):
    s = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(s)
    s.loader.exec_module(m)
    return m


mirror = load("port_swift_mirror", ROOT / "integrate-v2" / "port_swift_mirror.py")

SESSION = ROOT / "bench-prep" / "session-lines"
files = sorted(SESSION.glob("*.txt"))


def lines_of(path):
    return [(t.strip(), 0.9) for t in path.read_text(errors="replace").splitlines()
            if t.strip()]


def run_case(label, lines, errors, timings):
    t0 = time.perf_counter()
    try:
        mirror.parse(lines, fixed=True)
        dt = time.perf_counter() - t0
        timings.append((dt, label))
    except Exception:
        errors.append((label, traceback.format_exc(limit=3)))


def main():
    errors, timings = [], []
    rng = random.Random(20261111)

    for p in files:
        base = lines_of(p)
        run_case(f"{p.name}:orig", base, errors, timings)
        sh = base[:]
        rng.shuffle(sh)
        run_case(f"{p.name}:shuffle", sh, errors, timings)
        run_case(f"{p.name}:half", base[: len(base) // 2], errors, timings)
        run_case(f"{p.name}:triple", base * 3, errors, timings)
        run_case(f"{p.name}:reverse", base[::-1], errors, timings)
        noisy = []
        for t, c in base:
            if "." in t and any(ch.isdigit() for ch in t):
                t = t + " 99999999999999999999.99 @@##"
            noisy.append((t, c))
        run_case(f"{p.name}:noise", noisy, errors, timings)

    edge = {
        "empty": [],
        "one-line": [("TOTAL 1.00", 0.9)],
        "giant-money": [("STORE X", 0.9), ("ITEM Y 99999999999999999999.99", 0.9),
                        ("SUBTOTAL 99999999999999999999.99", 0.9),
                        ("TOTAL 99999999999999999999.99", 0.9)],
        "money-17digit": [("ITEM Y 99999999999999999.99", 0.9),
                          ("SUBTOTAL 99999999999999999.99", 0.9)],
        "symbols-only": [("@@##$$%%", 0.9)] * 50,
        "qty-zero": [("ITEM A 2 @ 0.00", 0.9), ("0 @ 5.00 0.00", 0.9),
                     ("SUBTOTAL 0.00", 0.9), ("TOTAL 0.00", 0.9)],
        "long-line": [("A" * 5000 + " 12.34", 0.9), ("TOTAL 12.34", 0.9)],
    }
    for label, ls in edge.items():
        run_case(f"edge:{label}", ls, errors, timings)

    big_src = max(files, key=lambda p: len(lines_of(p)))
    big = lines_of(big_src)
    run_case(f"edge:5000-lines({big_src.name}x{5000 // max(1, len(big)) + 1})",
             big * (5000 // max(1, len(big)) + 1), errors, timings)

    timings.sort(reverse=True)
    print(f"files={len(files)} cases={len(timings) + len(errors)} "
          f"errors={len(errors)}")
    print("top-5 slowest:")
    for dt, label in timings[:5]:
        print(f"  {dt:.3f}s {label}")
    if errors:
        print("ERRORS:")
        for label, tb in errors:
            print(f"--- {label}\n{tb}")
    else:
        print("NO EXCEPTIONS in any case.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
