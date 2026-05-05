# #tutorials — Statistics & Bioinformatics

Comprehensive, runnable tutorials in statistics and bioinformatics, with
R code throughout.

**Live site:** <https://cttir.github.io/tutorials/>

## Site structure

The top-level navigation is organised around four pillars:

- **Tutorials** — dropdown of all 16 topic areas, plus the full A–Z
  index at `tutorials.qmd`.
- **Applications** — interactive resources: the decision tree
  (wizard + static chart) and the 16 Shiny apps.
- **Overview** — `overview.qmd`: every tutorial in one place,
  filterable by topic and label, plus a tag-similarity network graph
  in which each node is a tutorial and edges link tutorials sharing
  ≥ 2 tags. Click a node to jump straight to the tutorial.
- **About** and **Impressum** — author and legal notice
  (per § 5 TMG).

Every tutorial page automatically shows a **Related tutorials** block
at the bottom — the three closest tutorials by tag-Jaccard similarity,
with a link back to the network graph for further exploration.

## What's here

- **569 method pages** across 16 topic areas — from foundational
  probability through Bayesian inference, survival analysis,
  bioinformatics pipelines, and clinical biostatistics.
- **Decision-tree section** — an interactive wizard plus a static
  Mermaid chart that guide the reader from research question to the
  appropriate statistical test, with reporting templates for each.
- **Shiny apps** — one interactive companion app per topic area.
- Every tutorial follows the same nine-section template
  (Introduction → Prerequisites → Theory → Assumptions →
  R Implementation → Output & Results → Interpretation → Practical Tips
  → Reporting), so the reader always knows where to find what they
  need.

## Topic areas

Statistical Foundations · Descriptive Statistics · Probability Theory ·
Inferential Statistics · Sample Size & Power · Data Visualisation ·
Regression & Modelling · Multivariate Methods · Time-Series Analysis ·
Bayesian Statistics · Survival Analysis · Bioinformatics ·
Machine Learning · Clinical Biostatistics · Meta-Analysis ·
Experimental Design.

## Building locally

The site is built with [Quarto](https://quarto.org). R 4.4.1 and
30 packages are pinned in `renv.lock`.

```bash
# Restore R environment
Rscript -e 'renv::restore()'

# Live preview (incremental, watches source files)
quarto preview

# Full render to docs/
quarto render
```

## Quality checks

```bash
# Prose-length audit (VG Wort METIS, threshold = 1,800 chars)
python scripts/vgwort_audit.py --csv vgwort_audit.csv

# Decision-tree wizard state-machine tests
node --test scripts/wizard-test.mjs

# Rebuild the tutorial manifest used by the Overview page and the
# auto-injected "Related tutorials" block on every tutorial.
python scripts/build_manifest.py    # writes js/tutorials-manifest.json
```

## Repository conventions

- Content lives in `tutorials/<category>/<slug>.qmd` and
  `decision-tree/...`.
- All R examples must be runnable against the packages in `renv.lock`,
  use `set.seed(42)` or `set.seed(2026)`, and avoid pseudocode.
  decision-tree coverage map, and `ORIGINALITY.md` for the originality
  statement.

## Citation

If you use this tutorial collection in teaching, research, or other written work, please cite it as:

```bibtex
@misc{heller2026tutorials,
  author       = {Heller, R.},
  title        = {{\#}tutorials: Comprehensive Tutorials in Statistics and Bioinformatics with {R}},
  year         = {2026},
  howpublished = {\url{https://cttir.github.io/tutorials/}},
  note         = {CTTIR project}
}
```

## Licence

MIT. See `LICENSE`.
