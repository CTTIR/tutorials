"""Build per-tutorial 'Related tutorials' partials at render time.

For every tutorial node in artifacts/graph.json, write an HTML fragment
to _includes/related/<topic>__<slug>.html containing the top-3 related
tutorials. The Lua filter at _filters/related-include.lua reads the
matching fragment and appends it to each tutorial's rendered output.

Ranking, in priority order:
  1. Sum of edge weights to candidate tutorials (the same edges
     that drive the network graph).
  2. Same-topic tiebreaker (small bonus so close-topic pages surface
     when tag overlap is sparse).
  3. Recency (more recent date wins) when scores are still tied.

This replaces the client-side js/related.js: every tutorial page now
ships its Related list as static HTML, with zero JS requests.

Run as a Quarto pre-render step (after build_graph.py).
"""
from __future__ import annotations

import html
import json
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GRAPH = ROOT / "artifacts" / "graph.json"
OUT = ROOT / "_includes" / "related"

K = 3                # how many neighbours to surface per tutorial
TOPIC_BONUS = 0.05   # small score nudge for same-topic candidates


def main() -> int:
    if not GRAPH.exists():
        print(
            f"build_related: {GRAPH.relative_to(ROOT)} not found — "
            f"run build_graph.py first",
            file=sys.stderr,
        )
        return 1
    data = json.loads(GRAPH.read_text(encoding="utf-8"))
    nodes = data["nodes"]
    edges = data["edges"]
    topic_label = {t["id"]: t["label"] for t in data.get("topics", [])}

    # Adjacency: id -> list of (neighbour_id, weight)
    adj: dict[str, list[tuple[str, int]]] = defaultdict(list)
    for e in edges:
        adj[e["source"]].append((e["target"], e["weight"]))
        adj[e["target"]].append((e["source"], e["weight"]))

    by_id = {n["id"]: n for n in nodes}

    OUT.mkdir(parents=True, exist_ok=True)
    written = 0
    skipped_no_neighbours = 0

    for self_node in nodes:
        self_id = self_node["id"]
        scored: dict[str, float] = {}
        for nbr_id, w in adj.get(self_id, []):
            if nbr_id == self_id:
                continue
            scored[nbr_id] = scored.get(nbr_id, 0.0) + float(w)

        # Topic-bonus + recency tiebreaker.
        ranked = sorted(
            scored.items(),
            key=lambda kv: (
                -(kv[1] + (TOPIC_BONUS if by_id[kv[0]]["topic"] == self_node["topic"] else 0.0)),
                -_year_key(by_id[kv[0]].get("date", "")),
                kv[0],
            ),
        )
        top = [by_id[i] for i, _ in ranked[:K]]

        if not top:
            skipped_no_neighbours += 1
            # Emit an empty file anyway so the Lua filter has something to
            # find; this prevents accidental fallback to a stale partial.
            partial_path(self_id).write_text("", encoding="utf-8")
            continue

        partial_path(self_id).write_text(render(self_node, top, topic_label), encoding="utf-8")
        written += 1

    print(
        f"build_related: wrote {written} partials, "
        f"{skipped_no_neighbours} tutorials had no neighbours -> {OUT.relative_to(ROOT)}/"
    )
    return 0


def partial_path(node_id: str) -> Path:
    # node_id is "<topic-slug>/<page-slug>"; flatten to one filename so
    # the Lua filter can compute it without recreating subdirs.
    return OUT / (node_id.replace("/", "__") + ".html")


def _year_key(date: str) -> int:
    try:
        return int(date[:4])
    except (ValueError, TypeError):
        return 0


def render(self_node: dict, top: list[dict], topic_label: dict[str, str]) -> str:
    tags_preview = (self_node.get("tags") or [])[:4]
    tags_text = ""
    if tags_preview:
        # Strip the synthetic "topic:<slug>" tag from the user-facing
        # blurb so the explanation reads naturally.
        visible = [t for t in tags_preview if not t.startswith("topic:")][:4]
        if visible:
            tags_text = " (" + ", ".join(html.escape(t) for t in visible) + ")"

    items = []
    for n in top:
        topic_disp = topic_label.get(n["topic"], n["topic"])
        # n["url"] is "tutorials/<topic>/<slug>.html" relative to the
        # site root. From a tutorial page (tutorials/<topic>/<slug>.html)
        # the link to another tutorial is "../<topic>/<slug>.html".
        url = n["url"].replace("tutorials/", "../", 1)
        title = html.escape(n["title"])
        topic_html = html.escape(topic_disp)
        desc = n.get("summary") or ""
        desc_html = (
            f'<div class="related-desc">{html.escape(desc)}</div>' if desc else ""
        )
        items.append(
            '<div class="related-item">'
            f'<span class="topic">{topic_html}</span>'
            f'<a href="{html.escape(url, quote=True)}">{title}</a>'
            f"{desc_html}"
            "</div>"
        )

    return (
        '<section class="related-tutorials" data-render="static">\n'
        "<h2>Related tutorials</h2>\n"
        f'<p class="related-blurb">Closest matches by shared tags{tags_text}.</p>\n'
        f'<div class="related-list">{"".join(items)}</div>\n'
        '<p class="network-link">'
        # Tutorials live at tutorials/<topic>/<slug>.html, so overview is
        # always two levels up. No site-prefix needed: relative paths
        # work under both root and GitHub Pages subpath hosting.
        '<a href="../../overview.html">Explore the full tag network &rarr;</a>'
        "</p>\n"
        "</section>\n"
    )


if __name__ == "__main__":
    sys.exit(main())
