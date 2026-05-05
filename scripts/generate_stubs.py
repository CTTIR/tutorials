#!/usr/bin/env python3
"""Generate tutorial stub markdown files from per-category data files.

Each data file lives in scripts/curriculum/<category-slug>.txt and uses the
pipe-delimited format:

    slug|Title|hint keywords

Lines beginning with '#' or blank lines are ignored. The generator walks every
data file and writes content/tutorials/<category>/<slug>.md as a draft stub
with a GENERATION PROMPT comment block for follow-up execution.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CURRICULUM_DIR = ROOT / "scripts" / "curriculum"
CONTENT_DIR = ROOT / "content" / "tutorials"

CATEGORY_META = {
    "statistical-foundations": {
        "title": "Statistical Foundations",
        "packages": ["stats", "ggplot2"],
    },
    "descriptive-statistics": {
        "title": "Descriptive Statistics",
        "packages": ["stats", "dplyr", "gt"],
    },
    "probability": {
        "title": "Probability Theory",
        "packages": ["stats", "ggplot2"],
    },
    "inference": {
        "title": "Inferential Statistics",
        "packages": ["stats", "effectsize", "broom"],
    },
    "sample-size": {
        "title": "Sample Size & Power",
        "packages": ["pwr", "pwrss"],
    },
    "visualisation": {
        "title": "Data Visualisation",
        "packages": ["ggplot2", "dplyr", "patchwork"],
    },
    "regression-modelling": {
        "title": "Regression & Modelling",
        "packages": ["stats", "broom", "performance", "ggplot2"],
    },
    "multivariate": {
        "title": "Multivariate Statistics",
        "packages": ["FactoMineR", "factoextra", "cluster"],
    },
    "time-series": {
        "title": "Time Series Analysis",
        "packages": ["forecast", "fable", "tsibble", "feasts"],
    },
    "bayesian": {
        "title": "Bayesian Statistics",
        "packages": ["brms", "rstan", "tidybayes", "bayesplot"],
    },
    "survival-analysis": {
        "title": "Survival Analysis",
        "packages": ["survival", "survminer", "flexsurv"],
    },
    "bioinformatics": {
        "title": "Bioinformatics",
        "packages": ["Biostrings", "DESeq2", "edgeR", "limma"],
    },
    "machine-learning": {
        "title": "Machine Learning",
        "packages": ["tidymodels", "recipes", "yardstick"],
    },
    "clinical-biostatistics": {
        "title": "Clinical Biostatistics",
        "packages": ["gtsummary", "pROC", "rpact"],
    },
    "meta-analysis": {
        "title": "Meta-Analysis",
        "packages": ["meta", "metafor", "dmetar"],
    },
    "experimental-design": {
        "title": "Experimental Design",
        "packages": ["agricolae", "AlgDesign", "rsm", "FrF2"],
    },
}

STUB_TEMPLATE = '''+++
title = "{title}"
description = "{hint}"
date = 2026-04-17
draft = true
categories = ["{category_title}"]
tags = [{tag_list}]
difficulty = "Intermediate"
packages = [{pkg_list}]
status = "stub"
toc = true
+++

<!--
GENERATION PROMPT (execute in the second, per-category pass):

Topic: {title}
Category: {category_title}
Outline hint: {hint}

Write a complete, self-contained tutorial following the nine-section
structure used across the site:

  1. Introduction    -- what it is, when to use it, why it matters
  2. Prerequisites   -- what the reader should know first
  3. Theory          -- mathematical/conceptual background, LaTeX for formulas
  4. Assumptions     -- what must hold for valid application
  5. R Implementation -- runnable code using the listed packages
  6. Output & Results -- sample R output and what it means
  7. Interpretation  -- how to report results in a manuscript
  8. Practical Tips  -- common pitfalls and best practices

Requirements:
- Exceed 1,800 characters of prose outside code blocks (VG Wort eligible).
- R code must actually run; no pseudocode, no placeholder package names.
- Use simulated or built-in data so the example is reproducible.
- When done, remove `draft = true` and change `status = "stub"` to
  `status = "complete"`.
-->

## Introduction

TODO: Introduce {title}. Motivate its place in {category_title} and the
practical research question it answers.

## Prerequisites

TODO: List the concepts a reader should already know.

## Theory

TODO: Present the mathematical/conceptual background with the key formulas in
LaTeX.

## Assumptions

TODO: List the assumptions required for valid application, and how to check
each one.

## R Implementation

```r
# TODO: Runnable example. Suggested packages: {pkg_list_plain}
# Use simulated or a built-in dataset; show the full pipeline end-to-end.
```

## Output & Results

TODO: Show typical R output and walk through each numeric summary.

## Interpretation

TODO: Demonstrate how to summarise the results for a manuscript or report.

## Practical Tips

TODO: Highlight the common pitfalls, extensions, and best practices.
'''


def slug_to_tags(slug: str) -> list[str]:
    parts = [p for p in slug.split("-") if p and len(p) > 1]
    return parts[:6]


def parse_curriculum_file(path: Path) -> list[tuple[str, str, str]]:
    entries: list[tuple[str, str, str]] = []
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        pieces = [p.strip() for p in line.split("|")]
        if len(pieces) != 3:
            print(f"warn: malformed line in {path.name}: {line!r}", file=sys.stderr)
            continue
        entries.append(tuple(pieces))
    return entries


def render_stub(category_slug: str, slug: str, title: str, hint: str) -> str:
    meta = CATEGORY_META[category_slug]
    pkgs = meta["packages"]
    tags = slug_to_tags(slug)
    return STUB_TEMPLATE.format(
        title=title,
        hint=hint,
        category_title=meta["title"],
        tag_list=", ".join(f'"{t}"' for t in tags),
        pkg_list=", ".join(f'"{p}"' for p in pkgs),
        pkg_list_plain=", ".join(pkgs),
    )


def main() -> int:
    created = 0
    skipped = 0
    per_category: dict[str, int] = {}
    for data_file in sorted(CURRICULUM_DIR.glob("*.txt")):
        category_slug = data_file.stem
        if category_slug not in CATEGORY_META:
            print(f"warn: unknown category {category_slug}", file=sys.stderr)
            continue
        out_dir = CONTENT_DIR / category_slug
        out_dir.mkdir(parents=True, exist_ok=True)
        count = 0
        for slug, title, hint in parse_curriculum_file(data_file):
            out_path = out_dir / f"{slug}.md"
            if out_path.exists():
                skipped += 1
                continue
            out_path.write_text(render_stub(category_slug, slug, title, hint))
            created += 1
            count += 1
        per_category[category_slug] = count
    print(f"created {created} stub(s); skipped {skipped} (already exist)")
    for cat, n in sorted(per_category.items()):
        print(f"  {cat}: +{n}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
