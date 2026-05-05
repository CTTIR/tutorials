#!/usr/bin/env python3
"""
VG Wort compliance audit for tutorial .qmd pages.

Prints a per-file character count of prose (frontmatter and fenced code
blocks stripped) and flags pages below the 1,800-character VG Wort METIS
threshold. Exit code is non-zero if any page under tutorials/ is short,
so the script is suitable for CI use.

Run from repository root:

    python scripts/vgwort_audit.py
    python scripts/vgwort_audit.py --threshold 2000
    python scripts/vgwort_audit.py --csv audit.csv
"""

from __future__ import annotations

import argparse
import csv
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

FRONTMATTER = re.compile(r"^---\s*\n.*?\n---\s*\n", re.S)
FENCED = re.compile(r"```.*?```", re.S)
INLINE = re.compile(r"`[^`]*`")
WHITESPACE = re.compile(r"\s+")


def prose_length(text: str) -> int:
    fm = FRONTMATTER.match(text)
    if fm:
        text = text[fm.end():]
    text = FENCED.sub("", text)
    text = INLINE.sub("", text)
    return len(WHITESPACE.sub(" ", text).strip())


def iter_qmd(root: Path):
    for dirpath, _, filenames in os.walk(root):
        for name in filenames:
            if name.endswith(".qmd") and name != "index.qmd":
                yield Path(dirpath) / name


def main() -> int:
    parser = argparse.ArgumentParser(description="VG Wort prose length audit")
    parser.add_argument("--root", default="tutorials",
                        help="Directory to scan (default: tutorials)")
    parser.add_argument("--threshold", type=int, default=1800,
                        help="Minimum prose chars (default: 1800)")
    parser.add_argument("--csv", metavar="PATH",
                        help="Write full per-file results to this CSV")
    args = parser.parse_args()

    root = Path(args.root)
    if not root.is_dir():
        print(f"error: {root} is not a directory", file=sys.stderr)
        return 2

    rows = []
    by_category: dict[str, list[int]] = defaultdict(lambda: [0, 0])

    for path in sorted(iter_qmd(root)):
        text = path.read_text(encoding="utf-8")
        n = prose_length(text)
        rel = path.relative_to(root)
        category = rel.parts[0] if len(rel.parts) > 1 else "_root"
        rows.append((str(path).replace("\\", "/"), category, n))
        by_category[category][1] += 1
        if n < args.threshold:
            by_category[category][0] += 1

    short = [(p, n) for p, _, n in rows if n < args.threshold]

    print(f"Scanned: {len(rows)} tutorial pages under {root}/")
    print(f"Threshold: {args.threshold} characters of prose")
    print(f"Below threshold: {len(short)}")
    print()
    print(f"{'Category':28s}  short / total   pct")
    for cat in sorted(by_category):
        s, t = by_category[cat]
        pct = (100 * s) // t if t else 0
        print(f"{cat:28s}  {s:4d} / {t:4d}   {pct:3d}%")

    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(["path", "category", "prose_chars", "below_threshold"])
            for p, c, n in rows:
                w.writerow([p, c, n, n < args.threshold])
        print(f"\nWrote {args.csv}")

    if short:
        print("\nShortest 20 pages:")
        for p, n in sorted(short, key=lambda x: x[1])[:20]:
            print(f"  {n:5d}  {p}")

    return 1 if short else 0


if __name__ == "__main__":
    sys.exit(main())
