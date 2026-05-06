#!/usr/bin/env python3
"""Build the Pagefind static search index over docs/tutorials/.

Run as a Quarto `post-render` step (see _quarto.yml) and from CI
(`.github/workflows/publish.yml`). Cross-platform — calls Pagefind via
`npx`, which is installed by the GitHub Actions setup-node action and
typically available in any local Node setup.

Index location: docs/pagefind/ (the Pagefind default for `--site docs`).
Scope: only tutorial pages (tutorials/**/*.html) — keeps the index small
and excludes wizard / decision-tree / impressum / etc.

Soft-skip if Node is unavailable so a `quarto preview` on a machine
without Node still works; CI fails hard via the gate in publish.yml.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"


def main() -> int:
    if not DOCS.exists():
        print(f"build_pagefind: skipped — {DOCS.relative_to(ROOT)} does not exist yet")
        return 0

    npx = shutil.which("npx") or shutil.which("npx.cmd")
    if not npx:
        print(
            "build_pagefind: WARNING — `npx` not found on PATH. "
            "Skipping search index build. Install Node.js to enable.",
            file=sys.stderr,
        )
        return 0

    cmd = [
        npx, "-y", "pagefind@latest",
        "--site", str(DOCS),
        "--glob", "tutorials/**/*.html",
        "--output-subdir", "pagefind",
    ]
    print("build_pagefind: " + " ".join(cmd))
    result = subprocess.run(cmd, cwd=ROOT)
    if result.returncode != 0:
        print(f"build_pagefind: ERROR — pagefind exited {result.returncode}", file=sys.stderr)
        return result.returncode

    # Sanity check.
    index_root = DOCS / "pagefind"
    if not (index_root / "pagefind.js").exists():
        print(
            f"build_pagefind: ERROR — expected {index_root.relative_to(ROOT)}/pagefind.js "
            f"after build, but it was not created",
            file=sys.stderr,
        )
        return 1
    print(f"build_pagefind: OK -> {index_root.relative_to(ROOT)}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
