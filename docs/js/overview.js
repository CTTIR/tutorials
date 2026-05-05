/* Overview page: filterable tutorial list + tag-similarity network graph.
   Loads /js/tutorials-manifest.json (built by scripts/build_manifest.py). */

(function () {
  "use strict";

  const TOPIC_COLORS = {
    "Statistical Foundations": "#1f77b4",
    "Descriptive Statistics":  "#aec7e8",
    "Probability Theory":      "#ff7f0e",
    "Inferential Statistics":  "#ffbb78",
    "Sample Size & Power":     "#2ca02c",
    "Data Visualisation":      "#98df8a",
    "Regression & Modelling":  "#d62728",
    "Multivariate Methods":    "#ff9896",
    "Time-Series Analysis":    "#9467bd",
    "Bayesian Statistics":     "#c5b0d5",
    "Survival Analysis":       "#8c564b",
    "Bioinformatics":          "#e377c2",
    "Machine Learning":        "#7f7f7f",
    "Clinical Biostatistics":  "#bcbd22",
    "Meta-Analysis":           "#17becf",
    "Experimental Design":     "#393b79",
  };

  const FALLBACK = "#888";

  function manifestUrl() {
    // Resolve against the site root the same way Quarto does for absolute /js paths.
    const base = document.querySelector('meta[name="quarto-site-url"]')?.content || "";
    return (base.replace(/\/$/, "") || "") + "/js/tutorials-manifest.json";
  }

  function detectRoot() {
    const brand = document.querySelector(".navbar-brand[href]");
    if (brand) {
      const h = brand.getAttribute("href");
      if (h && h !== "#") return h.endsWith("/") ? h : h.replace(/[^/]*$/, "");
    }
    return "";
  }

  async function loadManifest() {
    const root = detectRoot();
    const candidates = [
      root + "js/tutorials-manifest.json",
      "js/tutorials-manifest.json",
      "../js/tutorials-manifest.json",
    ];
    for (const url of candidates) {
      try {
        const r = await fetch(url, { cache: "no-cache" });
        if (r.ok) return await r.json();
      } catch (_) { /* try next */ }
    }
    throw new Error("tutorials-manifest.json not reachable");
  }

  function jaccard(a, b) {
    if (!a.length || !b.length) return 0;
    const sa = new Set(a);
    let inter = 0;
    for (const x of b) if (sa.has(x)) inter++;
    const union = sa.size + b.length - inter;
    return union ? inter / union : 0;
  }

  function sharedTagCount(a, b) {
    if (!a.length || !b.length) return 0;
    const sa = new Set(a);
    let n = 0;
    for (const x of b) if (sa.has(x)) n++;
    return n;
  }

  function unique(arr) { return Array.from(new Set(arr)); }

  function el(tag, attrs = {}, ...children) {
    const node = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) {
      if (k === "class") node.className = v;
      else if (k === "dataset") Object.assign(node.dataset, v);
      else if (k.startsWith("on") && typeof v === "function") node.addEventListener(k.slice(2), v);
      else node.setAttribute(k, v);
    }
    for (const c of children) {
      if (c == null) continue;
      node.append(c.nodeType ? c : document.createTextNode(c));
    }
    return node;
  }

  function init(data) {
    const tutorials = data.tutorials;
    const state = {
      activeTopics: new Set(),
      activeTags: new Set(),
    };

    // Resolve URLs relative to the site root using the navbar-brand
    // href, which Quarto rewrites per-page (e.g. "./" on overview.html,
    // "../../" from a deep tutorial). This works under both root and
    // GitHub Pages subpath hosting without any host-absolute paths.
    const root = (() => {
      const brand = document.querySelector(".navbar-brand[href]");
      if (brand) {
        const h = brand.getAttribute("href");
        if (h && h !== "#") return h.endsWith("/") ? h : h.replace(/[^/]*$/, "");
      }
      return "";
    })();

    function tutorialHref(t) {
      return root + t.url;
    }

    // ----- Filter bars -----
    const topicCounts = new Map();
    const tagCounts = new Map();
    for (const t of tutorials) {
      topicCounts.set(t.topic, (topicCounts.get(t.topic) || 0) + 1);
      for (const tag of t.tags) tagCounts.set(tag, (tagCounts.get(tag) || 0) + 1);
    }

    const topicBar = document.getElementById("topic-filter-bar");
    const tagBar = document.getElementById("tag-filter-bar");
    const summary = document.getElementById("filter-summary");
    const list = document.getElementById("tutorial-list");

    const topics = Array.from(topicCounts.keys()).sort();
    for (const topic of topics) {
      const chip = el("span", {
        class: "filter-chip",
        dataset: { active: "false", topic },
        onclick: () => { toggle(state.activeTopics, topic, chip); render(); },
        title: `Filter: ${topic}`,
      });
      const sw = el("span", { style: `display:inline-block;width:10px;height:10px;border-radius:50%;background:${TOPIC_COLORS[topic] || FALLBACK};margin-right:0.3rem;` });
      chip.append(sw, document.createTextNode(topic), el("span", { class: "chip-count" }, ` ${topicCounts.get(topic)}`));
      topicBar.appendChild(chip);
    }

    // Tags: limit visible chips to those that appear at least 3 times (still link-clickable from cards).
    const FREQ_TAG_THRESHOLD = 3;
    const freqTags = Array.from(tagCounts.entries())
      .filter(([, n]) => n >= FREQ_TAG_THRESHOLD)
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));

    for (const [tag, count] of freqTags) {
      const chip = el("span", {
        class: "filter-chip",
        dataset: { active: "false", tag },
        onclick: () => { toggle(state.activeTags, tag, chip); render(); },
        title: `Filter: ${tag}`,
      }, tag, el("span", { class: "chip-count" }, ` ${count}`));
      tagBar.appendChild(chip);
    }

    function toggle(set, value, chip) {
      if (set.has(value)) { set.delete(value); chip.dataset.active = "false"; }
      else { set.add(value); chip.dataset.active = "true"; }
    }

    function matches(t) {
      if (state.activeTopics.size && !state.activeTopics.has(t.topic)) return false;
      if (state.activeTags.size) {
        for (const tag of state.activeTags) if (!t.tags.includes(tag)) return false;
      }
      return true;
    }

    function render() {
      const filtered = tutorials.filter(matches);
      summary.textContent = `Showing ${filtered.length} of ${tutorials.length} tutorials.`
        + (state.activeTopics.size || state.activeTags.size
            ? ` Filters: ${[...state.activeTopics, ...state.activeTags].join(", ")}.`
            : "");

      list.replaceChildren();
      const frag = document.createDocumentFragment();
      for (const t of filtered.slice(0, 600)) {
        const card = el("article", { class: "tutorial-card" });
        const pill = el("span", {
          class: "topic-pill",
          style: `background:${TOPIC_COLORS[t.topic] || FALLBACK};color:#fff;`,
        }, t.topic);
        const h4 = el("h4", {}, el("a", { href: tutorialHref(t) }, t.title));
        const desc = t.description ? el("p", { class: "desc" }, t.description) : null;
        const tags = el("div", { class: "tags" });
        for (const tag of t.tags.slice(0, 6)) {
          tags.append(el("span", { class: "tag" }, tag));
        }
        card.append(pill, h4);
        if (desc) card.append(desc);
        card.append(tags);
        frag.append(card);
      }
      list.append(frag);
    }

    render();

    // ----- Network graph -----
    const networkContainer = document.getElementById("tutorial-network");
    if (!networkContainer || typeof vis === "undefined") return;

    const SHARED_TAG_THRESHOLD = 2;
    const nodes = tutorials.map((t, i) => ({
      id: i,
      label: t.title.length > 28 ? t.title.slice(0, 26) + "…" : t.title,
      title: `${t.title}\n${t.topic}\n${(t.tags || []).slice(0, 6).join(", ")}`,
      color: TOPIC_COLORS[t.topic] || FALLBACK,
      group: t.topic,
      url: tutorialHref(t),
    }));

    const edges = [];
    for (let i = 0; i < tutorials.length; i++) {
      for (let j = i + 1; j < tutorials.length; j++) {
        const shared = sharedTagCount(tutorials[i].tags, tutorials[j].tags);
        if (shared >= SHARED_TAG_THRESHOLD) {
          edges.push({ from: i, to: j, value: shared });
        }
      }
    }

    const visData = {
      nodes: new vis.DataSet(nodes),
      edges: new vis.DataSet(edges),
    };

    function themeColors() {
      const cs = getComputedStyle(document.documentElement);
      const fg = cs.getPropertyValue("--fg").trim() || "#222";
      const accent = cs.getPropertyValue("--accent").trim() || "#1a73e8";
      const bg = cs.getPropertyValue("--bg").trim() || "#ffffff";
      // Treat as dark if --bg is darker than mid-grey.
      const isDark = (() => {
        const m = bg.match(/^#?([0-9a-f]{6})$/i);
        if (!m) return false;
        const n = parseInt(m[1], 16);
        const r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
        return (r + g + b) / 3 < 128;
      })();
      return {
        nodeFont: fg,
        edge: isDark ? "rgba(200,200,200,0.18)" : "rgba(80,80,80,0.22)",
        edgeHighlight: accent,
      };
    }

    function themedOptions() {
      const c = themeColors();
      return {
        nodes: {
          shape: "dot",
          size: 8,
          font: { size: 10, color: c.nodeFont },
          borderWidth: 1,
        },
        edges: {
          color: { color: c.edge, highlight: c.edgeHighlight },
          smooth: false,
        },
        physics: {
          solver: "forceAtlas2Based",
          forceAtlas2Based: { gravitationalConstant: -40, springLength: 90, springConstant: 0.05 },
          stabilization: { iterations: 200 },
        },
        interaction: { hover: true, tooltipDelay: 200, navigationButtons: false },
      };
    }

    const network = new vis.Network(networkContainer, visData, themedOptions());

    // Re-skin when Quarto's color-scheme toggle is clicked.
    document.addEventListener("click", (ev) => {
      if (ev.target.closest && ev.target.closest(".quarto-color-scheme-toggle")) {
        // Defer until Quarto has swapped stylesheets.
        setTimeout(() => network.setOptions(themedOptions()), 60);
      }
    });
    network.on("click", (params) => {
      if (params.nodes.length) {
        const node = visData.nodes.get(params.nodes[0]);
        if (node && node.url) window.location.href = node.url;
      }
    });

    document.getElementById("network-reset")?.addEventListener("click", () => network.fit());

    const topicSel = document.getElementById("network-topic-filter");
    if (topicSel) {
      for (const topic of topics) {
        topicSel.append(el("option", { value: topic }, topic));
      }
      topicSel.addEventListener("change", () => {
        const sel = topicSel.value;
        if (!sel) {
          visData.nodes.update(nodes.map(n => ({ id: n.id, hidden: false })));
        } else {
          visData.nodes.update(nodes.map(n => ({ id: n.id, hidden: n.group !== sel })));
        }
      });
    }
  }

  document.addEventListener("DOMContentLoaded", () => {
    loadManifest()
      .then(init)
      .catch((e) => {
        const list = document.getElementById("tutorial-list");
        if (list) list.textContent = "Failed to load manifest: " + e.message;
        console.error(e);
      });
  });
})();
