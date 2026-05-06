// Filtered article list. Sorted newest-first by default. When a search
// query is active, sort order is supplied by the search layer (Phase 4)
// via an `orderHint: id[]`; until then, date-desc is the order.

import { makeMatcher } from "./state.js";

const MAX_RENDER = 600;

export function createList({ root, graph, topicById }) {
  const container = document.getElementById("tutorial-list");
  const empty = document.getElementById("tutorial-list-empty");

  function update(state, searchHits, orderHint = null, snippets = null) {
    const matches = makeMatcher(state, searchHits);
    let items = graph.nodes.filter(matches);

    if (orderHint && orderHint.length) {
      const rank = new Map(orderHint.map((id, i) => [id, i]));
      items.sort((a, b) => (rank.get(a.id) ?? 1e9) - (rank.get(b.id) ?? 1e9));
    } else {
      items.sort((a, b) => (b.date || "").localeCompare(a.date || ""));
    }

    container.replaceChildren();
    if (items.length === 0) {
      if (empty) empty.hidden = false;
      return;
    }
    if (empty) empty.hidden = true;

    const frag = document.createDocumentFragment();
    for (const t of items.slice(0, MAX_RENDER)) {
      frag.appendChild(renderCard(t, root, topicById, snippets?.get(t.id)));
    }
    container.appendChild(frag);
  }

  return { update };
}

function renderCard(t, root, topicById, snippetHTML) {
  const card = document.createElement("article");
  card.className = "tutorial-card";

  const topic = topicById.get(t.topic);
  const pill = document.createElement("span");
  pill.className = "topic-pill";
  pill.style.background = topic?.color || "#888";
  pill.style.color = "#fff";
  pill.textContent = topic?.label || t.topic;

  const h4 = document.createElement("h4");
  const a = document.createElement("a");
  a.href = root + t.url;
  a.textContent = t.title;
  h4.appendChild(a);

  card.appendChild(pill);
  card.appendChild(h4);

  if (snippetHTML) {
    // Pagefind returns excerpts containing <mark>…</mark> highlights —
    // sanitised by Pagefind itself, safe to insert as HTML.
    const p = document.createElement("p");
    p.className = "desc desc-snippet";
    p.innerHTML = snippetHTML;
    card.appendChild(p);
  } else if (t.summary) {
    const p = document.createElement("p");
    p.className = "desc";
    p.textContent = t.summary;
    card.appendChild(p);
  }

  if (t.tags && t.tags.length) {
    const tags = document.createElement("div");
    tags.className = "tags";
    for (const tag of t.tags.slice(0, 6)) {
      const s = document.createElement("span");
      s.className = "tag";
      s.textContent = tag;
      tags.appendChild(s);
    }
    card.appendChild(tags);
  }
  return card;
}
