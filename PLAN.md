# PLAN — overview page, tag network, search

Phase 1 plan, derived from `AUDIT.md` and the prompt's required improvements.
All 8 open questions resolved per the audit's recommendations (user agreed
"use recommendations" on 2026-05-06).

This plan is the contract for Phases 2–N. **No code changes happen until
the user approves this file.** Each phase below lands as one commit (or
PR if requested), with a render screenshot and a short summary.

---

## Resolved decisions (from audit open questions)

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Keep `categories` + folder convention.** Add **only** a new optional `labels:` key for the new label dimension (`beginner`, `intermediate`, `case-study`, `reference`, …). Do **not** migrate 569 files. | `categories[0]` already encodes the topic display name; `categories[1:]` are tags. The build pipeline parses this. Adding `labels:` is the smallest delta that gives us the third axis. |
| 2 | **Keep vis-network 9.1.9** for the force graph. **Add D3 v7** *only* for the heatmap. | vis-network is integrated, performant at 569 nodes, and the upgrade is about *linking* not *replacing*. D3 is the cleanest heatmap library. |
| 3 | **Introduce `_data/topics.yml`** as the single source of truth for `slug → display name → color → short description → order`. Both `build_manifest.py` and `build_indexes.py` import it; the JS layer receives it as part of `_artifacts/graph.json`. The two hardcoded copies (`TOPIC_COLORS`, `TOPIC_NAMES`, `CATEGORIES_ORDER`) are deleted. | Three drift sources collapse to one. CI can validate it. |
| 4 | **Pagefind replaces Quarto's default textsearch.** Quarto's `website.search:` is explicitly disabled; Pagefind drives both the global navbar search and the overview page filter. | Single index, scoped to tutorials only, on-demand WASM loading. Avoids two competing indexes. |
| 5 | **Tag chip combination logic flips to OR within category, AND across categories**, matching the prompt. Topics: OR. Tags: OR. Labels: OR. Combined: AND. | Matches user intent ("show me tutorials tagged X *or* Y"); current AND-within-tags is so strict it usually matches zero with >1 tag selected. |
| 6 | **CI gates phase in over two phases.** Phase 9a: front-matter validation, manifest freshness, topics.yml integrity, Pagefind index non-empty (hard fail). Phase 9b: Lighthouse a11y ≥ 95, no Quarto warnings, no commercial-link gate (hard fail after a remediation pass). | Strict gates on day one would block the very PR that introduces them. |
| 7 | **Pin Quarto to 1.6.43** in `_quarto.yml` (`quarto-required: ">=1.6.40"`) and in `publish.yml` (`with: { version: 1.6.43 }`). User can bump if their local is newer; we'll align to whatever `quarto --version` reports locally before Phase 2. | Reproducibility. The exact pin will be confirmed against the user's local install in Phase 2. |
| 8 | **Move generated artifacts out of git.** `js/tutorials-manifest.json` is replaced by `_artifacts/graph.json`, gitignored, built by a `pre-render:` hook in `_quarto.yml`. CI verifies the artifact exists post-render. | The current setup ships stale data silently; this is gap #1 in the audit. |

---

## Architecture summary

```
_data/topics.yml                # SoT: slug, display, color, order, blurb
                                # 16 entries

scripts/
  build_graph.py                # NEW: reads _data/topics.yml + all .qmd
                                # front matter, emits _artifacts/graph.json
                                # AND _artifacts/tutorials.csv
                                # AND _artifacts/cooccurrence.csv
                                # Run by Quarto pre-render hook.
  build_related.py              # NEW: reads _artifacts/graph.json,
                                # writes _includes/related/<slug>.html
                                # (replaces client-side js/related.js
                                # with a static HTML partial per page)
  build_pagefind.sh             # NEW: post-render Pagefind step
                                # (also wired into publish.yml)
  build_manifest.py             # KEPT but slimmed: now just emits the
                                # legacy js/tutorials-manifest.json shape
                                # for backward-compat during transition.
                                # Deleted at end of Phase 6.
  build_indexes.py              # MODIFIED to read _data/topics.yml
                                # instead of CATEGORIES_ORDER.

_artifacts/                     # gitignored, built at render time
  graph.json
  tutorials.csv
  cooccurrence.csv

_includes/related/<slug>.html   # gitignored, built at render time

assets/js/overview/             # NEW ES modules, single entry point
  main.js                       # bootstrap, wire components to state
  state.js                      # filterState + URL <-> Set sync
  graph.js                      # vis-network rendering, opacity-based filter
  search.js                     # Pagefind integration + debounce
  legend.js                     # topic chips + tag chips + label chips
  slider.js                     # noUiSlider date range
  heatmap.js                    # D3 co-occurrence
  list.js                       # filtered article list
  a11y.js                       # aria-live announcer + parallel nav

assets/scss/overview/
  _overview.scss                # consumes Quarto/Bootstrap CSS vars

overview.qmd                    # rewired to load main.js as a module

.github/workflows/publish.yml   # adds pre-render artifact build,
                                # post-render Pagefind, CI gates,
                                # Lighthouse + axe-core run
```

---

## Filter state contract

```ts
// Single source of truth, owned by state.js
type FilterState = {
  topics: Set<string>;   // OR within
  tags:   Set<string>;   // OR within
  labels: Set<string>;   // OR within
  query:  string;        // Pagefind query
  dateFrom: number;      // year
  dateTo:   number;      // year
};

// A node passes iff:
//   (topics.size === 0 || topics.has(node.topic))
//   && (tags.size === 0 || node.tags.some(t => tags.has(t)))
//   && (labels.size === 0 || node.labels.some(l => labels.has(l)))
//   && node.year >= dateFrom && node.year <= dateTo
//   && (query === "" || pagefindHits.has(node.id))
```

URL serialization: `?topics=a,b&tags=x,y&labels=l1&from=2024&to=2026&q=foo`,
written via `history.replaceState` (no history pollution).

Subscribers (graph, list, legend counts, heatmap, slider readout, URL):
all listen to a single `filterState.subscribe(fn)` and re-render with
smooth transitions. Non-matching graph nodes fade to ~10% opacity, never
removed (positions stable).

---

## `_data/topics.yml` shape

```yaml
- slug: statistical-foundations
  display: "Statistical Foundations"
  color: "#1f77b4"
  blurb: "Probability, estimators, asymptotics."
  order: 1
- slug: descriptive-statistics
  display: "Descriptive Statistics"
  color: "#aec7e8"
  blurb: "Summarising data without modelling assumptions."
  order: 2
# ... 16 entries total
```

The 16 colors are copied verbatim from the current
`js/overview.js::TOPIC_COLORS` so the visual identity stays the same on
day one. The `display` strings match the current `categories[0]` values
exactly, so no `.qmd` files need editing.

---

## Front-matter contract (post-upgrade)

```yaml
---
title: "..."
date: "YYYY-MM-DD"
description: "..."
categories:                    # unchanged
  - "<Topic Display Name>"     # MUST match a topics.yml display
  - "<tag-1>"                  # kebab-case
  - "<tag-2>"
labels:                        # NEW, optional
  - beginner                   # one or more of: beginner, intermediate,
                               # advanced, case-study, reference,
                               # methods, theory
---
```

`labels:` is **optional**. Tutorials without `labels:` are still indexed,
just absent from the label-chip filter. Phase 5 adds them gradually; we
do **not** bulk-edit 569 files.

---

## Phase breakdown (one commit per phase)

### Phase 2 — Foundation: `_data/topics.yml` + render-time artifact build

- Create `_data/topics.yml` with 16 entries (verbatim colors/names from
  current code).
- Write `scripts/build_graph.py` that:
  - Loads `_data/topics.yml`.
  - Walks `tutorials/**/*.qmd`, parses YAML front matter, validates
    `categories[0]` against topics.yml, collects tags from
    `categories[1:]`, reads optional `labels:`.
  - Computes nodes, edges (≥2 shared tags), per-topic/tag/label counts,
    co-occurrence pairs.
  - Writes `_artifacts/graph.json`, `_artifacts/tutorials.csv`,
    `_artifacts/cooccurrence.csv`.
  - Validates: every topic in topics.yml has ≥1 tutorial; no orphan
    `categories[0]`. Hard-fails with file-specific errors.
- Wire into `_quarto.yml`:
  ```yaml
  project:
    pre-render: scripts/build_graph.py
  ```
- `.gitignore` adds `_artifacts/`.
- Keep `build_manifest.py` running too (writes legacy
  `js/tutorials-manifest.json`) so the existing `overview.js` still
  works unmodified through this phase. Verifies parity with the new
  `graph.json`.
- **Acceptance:** `quarto render` produces `_artifacts/graph.json` with
  569 nodes; the old page still renders identically.

### Phase 3 — Linked filter state + new overview module

- New JS module skeleton under `assets/js/overview/`.
- `state.js`: filterState, URL serializer, pub/sub.
- `graph.js`: replaces vis-network setup from `js/overview.js`. Reads
  `_artifacts/graph.json`. Subscribes to filterState; updates node/edge
  opacity (does not destroy/recreate the network).
- `legend.js`: topic + tag + label chips with live counts. **OR within,
  AND across** combination logic.
- `list.js`: article list driven by filterState.
- `overview.qmd` switches its `<script>` to load
  `assets/js/overview/main.js` as a module. Old `js/overview.js` kept
  for one phase as a fallback (gated behind a feature flag in the page).
- **Headline test:** clicking a topic chip fades non-matching nodes,
  updates list, updates URL, updates tag-count badges. Reload restores
  the same view from the URL.
- **Acceptance:** all four components (graph, list, chips, URL) move
  in sync. Reset button clears state.

### Phase 4 — Pagefind search

- Disable Quarto's default search in `_quarto.yml`:
  ```yaml
  website:
    search: false
  ```
- Add `scripts/build_pagefind.sh` (post-render). Index limited to
  `docs/tutorials/`. Output to `docs/pagefind/`.
- `assets/js/overview/search.js`: search box on overview, 150ms debounce,
  feeds `filterState.query`. Snippets shown in the article list.
- Add a global navbar search input that uses the same Pagefind index
  but jumps to overview with `?q=...` populated.
- Wire `build_pagefind.sh` into `publish.yml` after `quarto render`.
- **Acceptance:** typing in the search box fades non-matching nodes
  and shows ranked snippets. Reload preserves query via URL.

### Phase 5 — Date slider + topic legend with counts

- Add `assets/js/overview/slider.js` using **noUiSlider** (vendored
  under `assets/vendor/nouislider/`, no CDN).
- `legend.js` upgraded to render topic chips with live counts (already
  scaffolded in Phase 3; this phase polishes accessibility, focus
  states, keyboard handling).
- Begin annotating ~50 high-traffic tutorials with `labels:` (manual
  pass; user-driven, not bulk-scripted). Label chips appear once any
  tutorial has labels.
- **Acceptance:** dragging the slider re-filters everything.
  Tab-navigable chips. Lighthouse a11y ≥ 90 on overview.

### Phase 6 — Tag co-occurrence heatmap + remove legacy

- `assets/js/overview/heatmap.js` using D3 v7 (vendored). Top-N tags
  via slider (default N=20, range 10–50). Heatmap recomputes against
  the filtered subset. Cell click → set tags filter to {i, j}.
- Collapsed `<details>` below the graph by default.
- **Remove** the legacy `js/overview.js` and the legacy
  `js/tutorials-manifest.json` (now `.gitignored` and regenerated).
- **Remove** `scripts/build_manifest.py` (replaced by `build_graph.py`).
- **Acceptance:** heatmap renders, clicks set filters, theme-aware
  colors. Repo no longer contains the legacy files.

### Phase 7 — Render-time related-tutorials partial

- Replace the client-side `js/related.js` with a render-time
  `scripts/build_related.py` that emits one `_includes/related/<slug>.html`
  per tutorial.
- A small Lua filter (or per-page `include-after-body:`) injects the
  matching partial into each tutorial.
- Static fallback if the partial is missing (no JS at all).
- **Acceptance:** every tutorial page shows a "Related tutorials"
  section with no JS request. `js/related.js` is deleted.

### Phase 8 — Mobile fallback + accessibility hardening

- `@media (max-width: 768px)` hides the network and the heatmap
  (collapsed to a sortable HTML table); search, chips, slider stay.
- Parallel `<nav aria-label="All tutorials">` always rendered, hidden
  on desktop with `.visually-hidden`.
- `aria-live="polite"` announcer for filter changes.
- All chips, slider handles, heatmap cells keyboard-accessible with
  visible focus rings.
- **Acceptance:** `axe-core` zero errors. Lighthouse a11y ≥ 95 on
  overview.

### Phase 9 — CI gates + downloads

- **9a (hard now):**
  1. Front-matter validator: every tutorial has `title`, `date`,
     `description`, `categories[0]` matching topics.yml.
  2. `_artifacts/graph.json` non-empty, edges > 0.
  3. Pagefind index non-empty.
  4. Every topic in topics.yml has ≥1 tutorial.
  5. No `external-commercial: true` without explicit allow.
- **9b (after remediation):**
  6. Quarto render emits zero warnings.
  7. Lighthouse a11y ≥ 95 on `overview.html`.
- "Download" dropdown on overview offering `graph.json`,
  `tutorials.csv`, `cooccurrence.csv` (already generated at render
  time, just exposed).
- `README-network.md` documenting the architecture, how to add a
  tutorial, how to extend topics.yml, troubleshooting.
- **Acceptance:** workflow fails loudly on injected violations of
  each gate.

---

## What this plan deliberately does **not** do

- Touch the Decision Tree app, Decision Assistant wizard, or Shiny apps.
- Change any tutorial body content.
- Rename or move any existing tutorial URL.
- Bulk-edit 569 `.qmd` files. The only edits to existing tutorials
  in this plan are *optional* `labels:` additions in Phase 5 and only
  to ~50 high-traffic ones.
- Replace vis-network with D3 for the network.
- Add user accounts, comments, or any server-side feature.

---

## Risk register

| Risk | Mitigation |
|------|------------|
| `pre-render:` script breaks `quarto preview` workflow | Script must be idempotent and fast (<5s for 569 files); skip work if `_artifacts/graph.json` is newer than every `.qmd`. |
| Pagefind index size on small tutorials with code blocks | Configure Pagefind to skip code blocks via `data-pagefind-ignore`. Measure index size; rollback to lunr if >2 MB. |
| vis-network opacity transitions janky on low-end mobile | Phase 8 mobile fallback hides the graph entirely below 768px. |
| URL params get long with many filters | Encode multi-value as comma-separated; cap at sensible length; the Reset button is always visible. |
| Topic color drift between dark and light themes | All non-topic colors come from CSS vars; topic colors stay constant intentionally (they're the identity signal). Documented in `README-network.md`. |
| Stale `_artifacts/` on dev machines | `.gitignore` + Quarto pre-render; CI is source of truth. |
| Lighthouse a11y < 95 in Phase 9b | Phase 8 explicitly targets a11y first; gate flipped only after remediation. |

---

## Approval gate

**Status:** Phase 1 complete. Awaiting user approval of this plan.
On approval, Phase 2 begins (`_data/topics.yml` + `build_graph.py` +
`pre-render` wiring). One commit, render screenshot, summary, then
pause for confirmation before Phase 3.

If anything in the resolved decisions or phase ordering needs to
change, say so and I'll revise this file before any code lands.

---

# Recon — landing avatar + linked #tutorials title (branch `feat/landing-avatar`)

## Title rendering surface

`index.qmd` carries both:

- YAML frontmatter `title: "#tutorials"` with `title-block-style: none`
  (Quarto's title block is suppressed)
- An explicit body H1 `# #tutorials` inside a `::: {.hero}` div

So the rendered H1 comes from the **body**, not the YAML title block.
Wrapping the body H1 in a Markdown link is the clean surface — no need to
remove the YAML `title:` (it still drives `<title>` and OG metadata) and no
custom title-block partial required.

## Existing navbar `#tutorials` link

Defined in `_quarto.yml` under `website.navbar.title: "#tutorials"`. Quarto
renders this as the `.navbar-brand` and auto-links it to the site root
(`https://cttir.github.io/tutorials/`). It is **not** defined in
`index.qmd` and will be left untouched.

## CSS surface

Themes wire `assets/light.scss` and `assets/dark.scss`, both of which pull
in `assets/_shared.scss`. Hero / kicker styles live in `_shared.scss`
(~lines 185–196). New `.ctir-avatar` / `.ctir-avatar-link` rules go there
so they apply in both themes.

## Plan

1. Insert the avatar `<a><img></a>` block at the top of the `.hero` div in
   `index.qmd`, immediately above `# #tutorials`. Avatar links to
   `https://cttir.github.io/website/`.
2. Wrap the H1 as `# [#tutorials](https://cttir.github.io/tutorials/)`.
3. Add `.ctir-avatar` / `.ctir-avatar-link` rules to `assets/_shared.scss`.
4. Cross-site image referenced live; do **not** copy into repo.
