"""Audit internal Markdown links in every .qmd file.

For each `[text](path)` or `[text](path#frag)` link whose target is not
an external URL, mailto, or anchor-only, resolve it relative to the
qmd's directory and check whether a corresponding file exists either
as `path` or `path` with .qmd <-> .html swapped. Prints (qmd, link,
resolved_target) for every broken one. Exit non-zero if any broken.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Markdown link with optional title (we ignore title) and a target.
# We capture the target only.
LINK_RE = re.compile(r"\[(?:[^\]]*)\]\(([^)\s#]+)(?:#[^)\s]*)?\s*(?:\"[^\"]*\")?\)")

# Skip anything matching these prefixes/patterns.
SKIP_PREFIXES = (
    "http://", "https://", "mailto:", "tel:", "ftp://", "data:",
    "/cdn-", "//",
)


def is_external_or_skip(target: str) -> bool:
    if not target:
        return True
    if target.startswith("#"):
        return True
    if target.startswith("?"):
        return True
    return target.lower().startswith(SKIP_PREFIXES)


def resolve(qmd: Path, target: str) -> Path | None:
    """Return absolute path to the file the link should resolve to,
    or None if it's untestable (e.g. directory without index)."""
    target = target.split("?", 1)[0]
    if target.startswith("/"):
        # Site-root relative.
        return ROOT / target.lstrip("/")
    return (qmd.parent / target).resolve()


def candidate_paths(p: Path) -> list[Path]:
    """All filesystem paths that could satisfy the link."""
    out = [p]
    s = p.suffix.lower()
    if s == ".html":
        out.append(p.with_suffix(".qmd"))
        out.append(p.with_suffix(".md"))
    elif s == ".qmd":
        out.append(p.with_suffix(".html"))
    elif s == "":
        out.append(p / "index.qmd")
        out.append(p / "index.html")
        out.append(p.with_suffix(".qmd"))
        out.append(p.with_suffix(".html"))
    return out


def main() -> int:
    broken: list[tuple[Path, str, Path]] = []
    qmd_files = list(ROOT.rglob("*.qmd"))
    # Skip rendered output and node_modules.
    qmd_files = [q for q in qmd_files if "docs" not in q.parts and "node_modules" not in q.parts and "_freeze" not in q.parts]

    for qmd in qmd_files:
        try:
            text = qmd.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        for m in LINK_RE.finditer(text):
            target = m.group(1).strip()
            if is_external_or_skip(target):
                continue
            resolved = resolve(qmd, target)
            if resolved is None:
                continue
            cands = candidate_paths(resolved)
            if not any(c.exists() for c in cands):
                broken.append((qmd.relative_to(ROOT), target, resolved.relative_to(ROOT) if resolved.is_relative_to(ROOT) else resolved))

    if not broken:
        print("OK — no broken internal links in .qmd source.")
        return 0

    by_qmd: dict[Path, list[tuple[str, Path]]] = {}
    for q, t, r in broken:
        by_qmd.setdefault(q, []).append((t, r))
    for q, items in sorted(by_qmd.items()):
        print(f"\n{q}")
        for t, r in items:
            print(f"  {t!r:60s}  ->  {r}")
    print(f"\nTOTAL broken: {len(broken)} across {len(by_qmd)} files.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
