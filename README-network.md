# Tag network, linked filters, and search — how it works

This document explains the overview-page architecture introduced by
the audit + plan recorded in `AUDIT.md` and `PLAN.md`. It is the
operating manual for anyone touching the overview page or the topic
taxonomy.

## High-level flow

```
tutorials/<topic>/<slug>.qmd   ──┐
                                  │  (front matter)
_data/topics.yml                  │
                                  ▼
                       scripts/build_graph.py        (pre-render)
                                  │
                                  ▼
                       artifacts/graph.json
                       artifacts/tutorials.csv
                       artifacts/cooccurrence.csv
                                  │
                                  ▼
                       scripts/build_related.py      (pre-render)
                                  │
                                  ▼
                       _includes/related/<slug>.html
                                  │
                       _filters/related-include.lua  (Quarto Lua filter)
                                  │
                                  ▼
                       docs/tutorials/<topic>/<slug>.html
                                  │
                                  ▼
                       scripts/build_pagefind.py     (post-render)
                                  │
                                  ▼
                       docs/pagefind/                (chunked WASM index)
```

The browser (overview.html) loads `assets/js/overview/main.js` as a
module, which fetches `artifacts/graph.json` and wires graph, list,
chips, search, slider, and heatmap to a single shared filter state.

## Single source of truth

`_data/topics.yml` is the only place that defines the 16 topic areas.
Every other consumer reads from it:

- `scripts/build_graph.py` validates each tutorial's `categories[0]`
  against `topics.yml` displays.
- `_artifacts/graph.json` exposes a `topics` array (id, label, color,
  count) for the JS layer.

If you need to rename a topic, change colour, or add a new topic, edit
`_data/topics.yml`, run `quarto render`, and the rest follows.

## Front matter contract

Every tutorial under `tutorials/<topic-slug>/<page-slug>.qmd` must have:

```yaml
---
title: "..."
date: "YYYY-MM-DD"
description: "..."
categories:
  - "<Topic Display Name>"   # MUST match a topics.yml display string
  - "<tag-1>"                # kebab-case, fine-grained
  - "<tag-2>"
labels:                       # OPTIONAL
  - beginner                  # one of: beginner | intermediate | advanced
  - case-study                # one of: case-study | reference | methods | theory
---
```

`build_graph.py` hard-fails the render with a file-specific message on:

- missing `title` / `date` / `description`
- empty `categories`
- `categories[0]` not matching any topics.yml display
- `labels:` containing a value not in the registry
  (`scripts/build_graph.py::ALLOWED_LABELS`)
- a topic in `topics.yml` with zero tutorials

## How filters compose

`assets/js/overview/state.js` owns the filter state:

```js
{
  topics: Set<string>,   // topic slugs
  tags:   Set<string>,   // tag ids
  labels: Set<string>,   // label ids
  query:  string,        // Pagefind query
  dateFrom, dateTo:      // year range
}
```

A node passes iff:

- `topics` is empty OR `topics.has(node.topic)`
- AND `tags` is empty OR at least one of `node.tags` is in `tags`
- AND `labels` is empty OR at least one of `node.labels` is in `labels`
- AND `dateFrom <= node.year <= dateTo`
- AND query is empty OR Pagefind matched the node

Combination logic is **OR within a category, AND across categories**.

URL state encodes everything:
`overview.html?topics=…&tags=…&labels=…&from=…&to=…&q=…`

## Tag enrichment

Tags exposed in `graph.json` are the union of:

1. `categories[1:]` from front matter (the explicit tags).
2. `topic:<slug>` (synthetic) so same-topic pages cluster.
3. Regex-derived mid-level tags (`bayesian-methods`, `time-to-event`,
   …) computed from title + description + slug. The pattern table is
   in `scripts/build_graph.py::MID_LEVEL_TAGS`.

Edge rule: two tutorials share an edge iff they share **≥ 2 tags**.
Edge weight is the count of shared tags. This is the same rule the
legacy in-browser graph used; the artifact has bit-exact parity.

## Adding a new tutorial

1. Create `tutorials/<topic-slug>/<page-slug>.qmd` with the front
   matter shown above.
2. Run `quarto render`. Pre-render validates metadata; post-render
   rebuilds the Pagefind index.
3. The overview page picks it up automatically — no further changes
   required.

If the topic is new:

1. Add a row to `_data/topics.yml`.
2. Create `tutorials/<new-slug>/index.qmd` (topic landing).
3. Add the topic to the navbar in `_quarto.yml`.
4. Render.

## Adding a new label

1. Append to `ALLOWED_LABELS` in `scripts/build_graph.py`.
2. Use it in tutorial front matter under `labels:`.
3. The legend renders the label chip automatically once at least one
   tutorial uses it.

## Build commands

```bash
# Full local render (pre-render + render + post-render)
quarto render

# Just rebuild the artifact (no Quarto needed)
python scripts/build_graph.py

# Just rebuild the related-tutorials partials
python scripts/build_graph.py
python scripts/build_related.py

# Just rebuild the Pagefind index (after a docs/ render)
python scripts/build_pagefind.py
```

## CI gates

`.github/workflows/publish.yml` enforces, post-render:

1. Front-matter validation (inside build_graph.py) — file-specific errors.
2. `artifacts/graph.json` non-empty, > 0 edges, every topic has ≥ 1 tutorial.
3. Pagefind index built (`docs/pagefind/pagefind.js` exists, entry index non-empty).
4. At least one related-tutorials partial emitted.

Phase 9b (deferred until a remediation pass) adds:

5. `quarto render --fail-if-warnings` (zero warnings tolerated).
6. Lighthouse a11y ≥ 95 on `overview.html`.
7. Link check via `lychee`.

## Troubleshooting

**"build_graph: ERROR — tutorials/X.qmd missing required front-matter
key 'description'"** — fix the front matter; the gate is intentional.

**Overview page renders but the network is empty** — check
`artifacts/graph.json` exists. If `quarto render` was bypassed, run
`python scripts/build_graph.py` directly. If `artifacts/` is missing
from the deployed site, confirm it's listed under
`project.resources` in `_quarto.yml`.

**Pagefind search returns nothing** — confirm `docs/pagefind/` was
created. If you see "Pagefind index unavailable" in the console,
either Node was missing during render, or the post-render hook
soft-skipped (warning printed). Install Node and re-render.

**Related tutorials section missing on a tutorial page** — confirm
`_includes/related/<topic>__<slug>.html` exists. If empty, the
tutorial has no graph neighbours (no other tutorial shares ≥ 2 tags
with it). Add explicit tags to widen the overlap.

## Architecture decisions (ADRs)

- **ADR-1: kept vis-network.** Already integrated, fine at 569 nodes.
  D3 swap would be a large change with no payoff. Heatmap uses vanilla
  SVG to avoid the D3 dep.
- **ADR-2: kept `categories[0]` = topic display.** No 569-file
  migration. The convention is enforced by the build script; future
  drift is caught at render time.
- **ADR-3: Pagefind, not lunr.** Smaller chunked index, on-demand
  WASM loading, native excerpt highlighting. Quarto's default lunr
  search is disabled.
- **ADR-4: opacity-based filter on the graph.** Non-matching nodes
  fade rather than vanish — preserves the spatial layout so the
  user's mental map of clusters survives across filters.
- **ADR-5: render-time related-tutorials partials.** Lua filter
  injects the static HTML; zero JS request per tutorial page.
- **ADR-6: dependency-light slider and heatmap.** Native dual-range
  inputs and vanilla SVG, instead of noUiSlider and D3, keep the
  bundle small and avoid vendoring binaries.
- **ADR-7: artifacts under `artifacts/`, not `_artifacts/`.** Quarto
  excludes underscore-prefixed directories from output; the rename
  lets the artifact ship through normal `resources:` handling.
