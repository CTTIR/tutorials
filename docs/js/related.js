/* Auto-injects a "Related tutorials" section at the end of every tutorial page.
   Uses /js/tutorials-manifest.json + tag Jaccard similarity to pick the top 3.
   No-ops on non-tutorial pages. */

(function () {
  "use strict";

  function detectSlug() {
    // Match /tutorials/<topic>/<slug>.html  (or trailing slash)
    const m = window.location.pathname.match(/\/tutorials\/([^\/]+)\/([^\/]+?)(?:\.html)?\/?$/);
    if (!m) return null;
    if (m[2] === "index") return null;
    return `${m[1]}/${m[2]}`;
  }

  async function loadManifest() {
    const root = siteRootHref();
    const candidates = [
      root + "js/tutorials-manifest.json",
      "../../js/tutorials-manifest.json",
      "../js/tutorials-manifest.json",
      "js/tutorials-manifest.json",
    ];
    for (const url of candidates) {
      try {
        const r = await fetch(url, { cache: "no-cache" });
        if (r.ok) return await r.json();
      } catch (_) { /* try next */ }
    }
    return null;
  }

  function similarity(a, b) {
    if (!a.length || !b.length) return 0;
    const sa = new Set(a);
    let inter = 0;
    for (const x of b) if (sa.has(x)) inter++;
    if (!inter) return 0;
    const union = sa.size + b.length - inter;
    return inter / union;
  }

  function pickRelated(self, all, k) {
    const scored = [];
    for (const t of all) {
      if (t.slug === self.slug) continue;
      let s = similarity(self.tags, t.tags);
      // Small boost for same topic so unrelated-but-close-topic pages still surface.
      if (t.topic === self.topic) s += 0.05;
      if (s > 0) scored.push({ t, s });
    }
    if (scored.length < k) {
      // Top up with same-topic siblings if tag similarity yielded too few.
      const have = new Set(scored.map(x => x.t.slug));
      for (const t of all) {
        if (scored.length >= k * 2) break;
        if (t.slug === self.slug || have.has(t.slug)) continue;
        if (t.topic === self.topic) scored.push({ t, s: 0.001 });
      }
    }
    scored.sort((a, b) => b.s - a.s);
    return scored.slice(0, k).map(x => x.t);
  }

  function siteRootHref() {
    // Quarto rewrites the navbar-brand href to point at the site index
    // page using a path that's correct regardless of GitHub Pages subpath
    // depth: "./" from the homepage, "../../" from /tutorials/<topic>/<slug>.html.
    // Strip any trailing filename (e.g. "../../index.html" -> "../../").
    const brand = document.querySelector(".navbar-brand[href]");
    if (brand) {
      const h = brand.getAttribute("href");
      if (h && h !== "#") {
        return h.endsWith("/") ? h : h.replace(/[^/]*$/, "");
      }
    }
    // Fallback: derive from the depth of the current path under the
    // tutorials/ directory. Tutorial pages are 2 levels deep.
    const m = window.location.pathname.match(/\/tutorials\/[^/]+\/[^/]+(?:\.html)?$/);
    return m ? "../../" : "";
  }

  function render(self, related) {
    const root = siteRootHref();
    const main = document.querySelector("main") || document.body;
    const wrap = document.createElement("section");
    wrap.className = "related-tutorials";
    wrap.innerHTML = `
      <h2>Related tutorials</h2>
      <p class="related-blurb">
        Closest matches by shared tags${self.tags.length ? ` (${self.tags.slice(0, 4).join(", ")}${self.tags.length > 4 ? "…" : ""})` : ""}.
      </p>
      <div class="related-list"></div>
      <p class="network-link">
        <a href="${root}overview.html">Explore the full tag network &rarr;</a>
      </p>
    `;
    const listEl = wrap.querySelector(".related-list");
    for (const r of related) {
      const item = document.createElement("div");
      item.className = "related-item";
      const url = `${root}${r.url}`;
      item.innerHTML = `
        <span class="topic">${r.topic}</span>
        <a href="${url}">${r.title}</a>
        ${r.description ? `<div class="related-desc">${r.description}</div>` : ""}
      `;
      listEl.appendChild(item);
    }
    main.appendChild(wrap);
  }

  document.addEventListener("DOMContentLoaded", async () => {
    const slug = detectSlug();
    if (!slug) return;
    const data = await loadManifest();
    if (!data) return;
    const self = data.tutorials.find(t => t.slug === slug);
    if (!self) return;
    const related = pickRelated(self, data.tutorials, 3);
    if (!related.length) return;
    render(self, related);
  });
})();
