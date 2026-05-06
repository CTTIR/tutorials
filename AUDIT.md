# AUDIT — overview page, tag network, search

Phase 0 of the network/search upgrade. Inventory of the **current** state, taken
from the live source tree at `C:\Users\raban\Documents\GitHub\CTTIR\tutorials`.
Nothing has been modified. Open questions are listed at the end and need user
input before Phase 1 (PLAN.md).

---

## 1. Build system

- **Quarto site root.** The Quarto project lives in `tutorials/` (not the repo
  root). The repo root contains many sibling R packages (`bambamR`, `cuvis.r`,
  …) and a separate Hugo project under `website/`. All Quarto-related paths
  below are relative to `tutorials/`.
- **`_quarto.yml`** declares `project.type: website`, `output-dir: docs`. ✅
- **Quarto version is *not* pinned.** Local builds depend on whatever Quarto
  the user has installed; CI uses `quarto-dev/quarto-actions/setup@v2` with no
  `version:` input, i.e. always latest. No `.quarto-version` / `_quarto.yml`
  pin. Should be pinned for reproducibility.
- **Tutorial format.** All 569 tutorials are `.qmd` (no `.ipynb`). Path scheme
  is `tutorials/<topic-slug>/<slug>.qmd`. Each topic also has an `index.qmd`
  landing page (skipped by the manifest builder).
- **Freeze.** `execute.freeze: auto`. `_freeze/` is gitignored; not present
  locally right now, so the next render will recompute everything.
- **Pre-render / post-render.** **None configured** in `_quarto.yml`. The
  manifest that drives both the network and the related-articles widget
  (`js/tutorials-manifest.json`) is built by `scripts/build_manifest.py` —
  but only when invoked manually. CI does not run it. The committed copy
  is what ships. This is the single biggest fragility in the current build.

## 2. Front matter / metadata

Front-matter keys actually used by tutorials (sampled across all 16 topics):

| Key           | Present in tutorials?                | Notes |
|---------------|--------------------------------------|-------|
| `title`       | yes (all)                            | |
| `date`        | yes                                  | ISO `YYYY-MM-DD` |
| `description` | yes                                  | one-line summary |
| `categories`  | yes (all 569)                        | mix of topic display name + 2–4 fine-grained kebab-case tags |
| `tags`        | **none** (0 files)                   | the proposed key does not exist yet |
| `labels`      | **none** (0 files)                   | the proposed key does not exist yet |
| `topic`       | **none** (0 files)                   | topic is derived from the parent folder, not declared in front matter |
| `difficulty`  | **none** (0 files)                   | `build_manifest.py` reads it but no tutorial sets it |
| `keywords`    | not seen                             | |

**Implications for the new design:**

- The `tags` / `labels` / `topic` keys called for in the prompt do **not**
  exist. Either we adopt them (front-matter migration across 569 files) or
  we keep the existing convention (`categories` + folder = topic) and adapt
  the new code. PLAN.md needs to pick one — no migration runs without sign-off.
- `categories` is currently overloaded: it contains both the topic display
  name (e.g. `Bayesian Statistics`) **and** fine-grained tags
  (`bayes-factor`, `model-comparison`). The manifest builder peels off the
  topic alias and treats the rest as tags. This works but means topic ↔ tag
  drift is invisible to the author.

**Single source of truth for topics → colour → label.** None on disk. The
mapping exists in **two parallel hardcoded constants** that will silently
drift apart:
- `scripts/build_manifest.py::TOPIC_NAMES` (slug → display name, 16 entries)
- `js/overview.js::TOPIC_COLORS` (display name → hex colour, 16 entries)

These should collapse into one `_data/topics.yml` consumed by both the
build script and the page (via Quarto include or generated JSON).

**Tag drift / consistency.** Not exhaustively audited. The mid-level-tag
heuristics in `build_manifest.py` (regex sweep over title+description+slug
to inject cross-cutting tags like `bayesian-methods`, `time-to-event`, …)
mask some of this drift but also create tags that authors didn't write —
which means tag chips in the UI may not match anything visible in the
source `.qmd`. Worth flagging in PLAN.md.

## 3. Existing network graph implementation

- **Library: `vis-network` 9.1.9**, loaded from `unpkg.com` via inline
  `<script src="https://unpkg.com/vis-network@9.1.9/standalone/umd/vis-network.min.js">`
  in `overview.qmd`. CDN, not pinned via SRI. Not vendored.
- **Where built:** entirely in the **browser**, on every page load, from
  `js/tutorials-manifest.json`. The double loop `for i; for j>i` over 569
  nodes is ~161 700 pair comparisons in JS on the main thread. Measurable
  cost on weaker devices; this is the prompt's stated target for moving
  to render time.
- **Edge rule:** `sharedTagCount(a.tags, b.tags) >= 2`, weight = shared
  count. Confirmed at `js/overview.js:207`–`225`. Matches the wording on
  the rendered page.
- **Graph data location:** there is **no** standalone `graph.json`. The
  manifest at `js/tutorials-manifest.json` is the only artifact;
  nodes/edges are derived from it client-side. The manifest **is** committed
  (tracked file), so the absent CI build step does not block deploys, but
  it does mean the manifest can fall behind `.qmd` changes without anyone
  noticing.
- **Node colour:** `TOPIC_COLORS` map in `js/overview.js`, hardcoded hex —
  not from CSS variables. Therefore node colours do **not** retheme on dark
  mode (only edge / font colour does, via `themeColors()` reading
  `--bg`/`--fg`/`--accent`). Visible inconsistency in dark mode.

## 4. Existing label filter

- **Driven by:** custom JS in `js/overview.js`. **Not** Quarto's native
  `listing:`. Two filter bars are rendered into pre-allocated divs in
  `overview.qmd` (`#topic-filter-bar`, `#tag-filter-bar`).
- **Updates on click:** the **article list** below and the
  `#filter-summary` text. **The graph does not respond.** The graph has its
  own, independent `#network-topic-filter` `<select>` for hiding non-matching
  nodes by topic only — no tag/label coupling. This is the headline gap.
- **Multi-select:** yes, multiple topic chips and multiple tag chips can be
  active at once. **Within-category combination logic is asymmetric and
  inconsistent with the proposal:**
  - Topics: AND across active topics — actually because activeTopics is
    a Set and a tutorial has exactly one topic, having two topics active
    means *zero* matches (any tutorial matches at most one). Effectively
    "single-topic mode" disguised as multi-select.
  - Tags: **AND** within tags — every active tag must appear in `t.tags`.
  - The proposal asks for **OR within category, AND across categories**.
    That's a behavioural change worth calling out before flipping it.
- **No URL state.** Refreshing or sharing the page loses the filter.

## 5. Existing search

- **Quarto site search:** **not configured**. `_quarto.yml` has no
  `website.search:` block. Quarto's default for `project.type: website` is
  to enable text search (`type: textsearch`, lunr-based) automatically
  unless explicitly disabled — so search **is** likely live in production
  via the default, but it is *not* declaratively tuned in this repo. The
  navbar does not include a search input slot configuration.
- **Custom search beyond Quarto:** none.
- **Search ↔ graph / labels:** none. They're entirely separate worlds.

This is roughly what the prompt predicted ("likely: no — that's the headline
gap to close").

## 6. Theming & dark mode

- **Theme:** Bootstrap-based via `flatly` (light) and `darkly` (dark)
  augmented with `assets/light.scss` and `assets/dark.scss`, plus a shared
  `assets/_shared.scss`.
- **Colour variables:** defined as CSS custom properties (`--bg`, `--fg`,
  `--fg-alt`, `--accent`, `--accent-hover`, `--rule`, …) in the per-palette
  SCSS files. The `_shared.scss` rules consume only those variables — no
  hex hardcoding. Topic colours, however, are **not** in SCSS — they live
  in JS (`TOPIC_COLORS`). Need to migrate to a single source if we want
  the legend, network nodes, and chips to retheme together.
- **Dark-mode mechanism:** Quarto's native `.quarto-color-scheme-toggle`
  button. Its click flips an attribute on the `<html>` element (Bootstrap
  conventionally `data-bs-theme="dark"|"light"`; Quarto uses a class on
  `<body>` plus the swapped stylesheet). The graph re-skins by listening
  for clicks on `.quarto-color-scheme-toggle` with a `setTimeout(60ms)` —
  fragile (loses programmatic toggles, OS-preference changes, and any
  toggle that doesn't bubble through that selector). A `MutationObserver`
  on the relevant attribute would be more robust, as the prompt suggests.
- **One-time localStorage reset shim** (`quarto-color-scheme-reset-v1`) is
  injected via `include-in-header:` to flush stale dark-mode prefs from
  before dark-mode-by-default. Worth preserving when we add new keys.

## 7. Deployment

- **GitHub Actions** at `.github/workflows/publish.yml`. Builds on `main`
  and `workflow_dispatch`. Renders with default Quarto, uploads
  `docs/` as the Pages artifact, deploys via `actions/deploy-pages@v4`.
  No `gh-pages` branch.
- **No CI quality gates.** No link check, no metadata validation, no
  Pagefind index, no manifest rebuild, no Lighthouse. The render itself
  emits warnings silently.
- The manifest builder script (`scripts/build_manifest.py`) is **not**
  invoked by CI. The committed `js/tutorials-manifest.json` is what ships.

## 8. Performance baseline

Not measured in this audit (no render run; happy to do this in Phase 1
once the user agrees the audit is correct). Order-of-magnitude
expectations to verify:

- `js/tutorials-manifest.json` for 569 entries with derived tags ≈ 0.3–
  0.5 MB inline equivalent. Currently committed to git.
- The pair loop runs every page load (~161k comparisons in JS).
- `vis-network` UMD is ~600 kB minified.
- No Lighthouse score on file. Will run on `overview.html` in Phase 1.

---

## Snapshot of the relevant files

```
tutorials/
  _quarto.yml                       # website config; no pre/post-render
  overview.qmd                      # hosts #tutorial-network, #*-filter-bar, #tutorial-list
  index.qmd                         # landing page (16 topic cards)
  tutorials.qmd                     # A–Z list
  about.qmd, impressum.qmd
  tutorials/<topic-slug>/<slug>.qmd # 569 tutorials, 16 topic folders
  tutorials/<topic-slug>/index.qmd  # per-topic landing
  scripts/
    build_manifest.py               # generates js/tutorials-manifest.json (manual)
    build_indexes.py                # (not yet inspected)
    link_audit.py                   # (not yet inspected)
    vgwort.lua                      # Lua filter (not pre-render)
    …
  js/
    tutorials-manifest.json         # committed, drives everything
    overview.js                     # vis-network setup, filters, in-browser
    related.js                      # client-side related-tutorials injector
    decision-tree-zoom.js, wizard.js
  css/
    overview.css                    # custom CSS (not SCSS)
    decision-tree.css, wizard.css
  assets/
    _shared.scss, light.scss, dark.scss  # Quarto theme overrides via CSS vars
  decision-tree/, shiny/, apps/     # out of scope per prompt
  docs/                             # rendered output (gitignored under .quarto)
  .github/workflows/publish.yml     # render → Pages
```

---

## Open questions for PLAN.md (need user input)

1. **Front-matter migration vs. retro-fit.** Do we add `topic:` /
   `tags:` / `labels:` keys to all 569 `.qmd` files, or keep `categories`
   + folder convention and adapt the new code to read it? The first is
   cleaner long-term; the second is a one-line change per file *or* zero
   if we adapt code. **Recommendation:** keep `categories` + folder, add
   only `labels:` for the new label dimension (`beginner`, `case-study`,
   …) since that genuinely doesn't exist today.
2. **Keep vis-network or swap?** `vis-network` is fine for the node count,
   handles physics/edges out of the box, and is already integrated.
   Swapping to D3/sigma is a larger change with no obvious payoff for
   this size. **Recommendation:** keep vis-network, add a small D3
   heatmap for §6, move computation to render time.
3. **Manifest single-source-of-truth.** Adopt `_data/topics.yml`
   consumed by both `build_manifest.py` and the page (via a generated
   JSON or a Quarto include). The current dual hardcoded maps will keep
   drifting otherwise. Confirm before I refactor the script.
4. **Search engine.** Pagefind is the prompt's preference. Adopting it
   means: (a) configuring Quarto's built-in search to OFF (or accepting
   both run), (b) adding a post-render step in CI, (c) bundling the
   chunked WASM index. Confirm: replace Quarto search, or run alongside?
5. **Within-category logic for tags.** Switch from current AND to the
   proposed OR? This *will* change which tutorials appear when a user
   has multiple tag chips active. Worth a one-line callout in release
   notes.
6. **CI gate strictness.** The prompt's gate list (e.g. fail build if
   any topic in `_data/topics.yml` has zero tutorials, fail if Lighthouse
   a11y < 95) is strict. Some of these will fail on first introduction
   and need a remediation pass before being enforced. PLAN.md will
   propose phasing them in.
7. **Quarto version pin.** Pin to the version currently used by the
   user locally? CI will need the same value.

---

**Status:** Phase 0 complete. Awaiting confirmation that this audit
matches reality before producing `PLAN.md`. No source files have been
modified.
