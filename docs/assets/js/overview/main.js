// Overview page entry point — wires graph, list, legend to a single
// shared filter state. Loaded as <script type="module"> from overview.qmd.
//
// Phase 3 scope: linked filter (topics/tags/labels chips, year range
// reads but no slider yet, no search yet). Pagefind is added in Phase 4,
// noUiSlider in Phase 5, heatmap in Phase 6.

import { createState } from "./state.js";
import { createGraph, bindResetButton } from "./graph.js";
import { createLegend } from "./legend.js";
import { createList } from "./list.js";
import { createSearch } from "./search.js";
import { createSlider } from "./slider.js";
import { createHeatmap } from "./heatmap.js";
import { createMobileNav } from "./mobile-nav.js";

function detectRoot() {
  const brand = document.querySelector(".navbar-brand[href]");
  if (brand) {
    const h = brand.getAttribute("href");
    if (h && h !== "#") return h.endsWith("/") ? h : h.replace(/[^/]*$/, "");
  }
  return "";
}

async function loadGraph(root) {
  const candidates = [root + "artifacts/graph.json", "artifacts/graph.json", "../artifacts/graph.json"];
  for (const url of candidates) {
    try {
      const r = await fetch(url, { cache: "no-cache" });
      if (r.ok) return await r.json();
    } catch (_) { /* try next */ }
  }
  throw new Error("artifacts/graph.json not reachable");
}

async function bootstrap() {
  const root = detectRoot();

  let graph;
  try { graph = await loadGraph(root); }
  catch (e) {
    document.getElementById("tutorial-list").textContent =
      "Failed to load tutorial network. Reload the page or report at https://github.com/CTTIR/tutorials/issues.";
    console.error(e);
    return;
  }

  const topicById = new Map(graph.topics.map(t => [t.id, t]));

  const years = graph.nodes.map(n => n.year).filter(Number.isFinite);
  const minYear = years.length ? Math.min(...years) : 2024;
  const maxYear = years.length ? Math.max(...years) : 2026;

  const controller = createState({ minYear, maxYear });

  const networkContainer = document.getElementById("tutorial-network");
  const graphView = createGraph({ container: networkContainer, graph, controller, root, topicById });
  const legend    = createLegend({ root, graph, controller, topicById });
  const list      = createList({ root, graph, topicById });
  const slider    = createSlider({ controller, minYear, maxYear });
  const heatmap   = createHeatmap({ controller, graph });
  const mobileNav = createMobileNav({ graph, topicById, root });

  // aria-live announcer: brief, throttled status announcements for
  // screen-reader users when the filter set changes.
  const announcer = document.getElementById("a11y-announcer");
  let announceTimer = null;
  function announce(state, total, matching) {
    if (!announcer) return;
    clearTimeout(announceTimer);
    announceTimer = setTimeout(() => {
      const filters = [];
      if (state.topics.size) filters.push(`${state.topics.size} topic${state.topics.size > 1 ? "s" : ""}`);
      if (state.tags.size)   filters.push(`${state.tags.size} tag${state.tags.size > 1 ? "s" : ""}`);
      if (state.labels.size) filters.push(`${state.labels.size} label${state.labels.size > 1 ? "s" : ""}`);
      if (state.query)       filters.push(`search "${state.query}"`);
      announcer.textContent = filters.length
        ? `${matching} of ${total} tutorials match (${filters.join(", ")}).`
        : `Showing all ${total} tutorials.`;
    }, 400);
  }

  bindResetButton(document.getElementById("network-reset"), graphView);

  // Search results are stored here so non-search subscribers (graph,
  // list, legend) can read the latest hits without re-querying Pagefind.
  let searchResult = { hits: null, snippets: new Map(), order: [] };

  function fanOut(s) {
    graphView.update(s, searchResult.hits);
    legend.update(s, searchResult.hits);
    list.update(s, searchResult.hits, searchResult.order, searchResult.snippets);
    slider.update(s);
    heatmap.update(s, searchResult.hits);
    mobileNav.update(s, searchResult.hits);

    // Compute matching count once for the announcer (matchers are cheap
    // but legend already iterates all nodes; kept simple here).
    let matching = 0;
    const m = (function () {
      // Reuse legend's no-overrides predicate via state directly.
      const matches = (n) => {
        if (s.topics.size && !s.topics.has(n.topic)) return false;
        if (s.tags.size && !n.tags.some(t => s.tags.has(t))) return false;
        if (s.labels.size && !n.labels.some(l => s.labels.has(l))) return false;
        if (n.year < s.dateFrom || n.year > s.dateTo) return false;
        if (searchResult.hits && !searchResult.hits.has(n.id)) return false;
        return true;
      };
      return matches;
    })();
    for (const n of graph.nodes) if (m(n)) matching++;
    announce(s, graph.nodes.length, matching);
  }

  const search = createSearch({
    root, graph, controller,
    onResults(result) { searchResult = result; fanOut(controller.state); },
  });

  let lastQuery = null;
  controller.subscribe((s) => {
    if (s.query !== lastQuery) {
      lastQuery = s.query;
      // Async; onResults() will fanOut once the index resolves.
      search.update(s);
    }
    fanOut(s);
  });

  controller.hydrateFromURL();
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", bootstrap);
} else {
  bootstrap();
}
