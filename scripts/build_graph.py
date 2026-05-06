#!/usr/bin/env python3
"""Build artifacts/graph.json (and CSV companions) from tutorial front matter.

Run by Quarto's pre-render hook (see _quarto.yml). The new overview module
loads artifacts/graph.json instead of the legacy js/tutorials-manifest.json.

Outputs (all under artifacts/, gitignored):
  graph.json          — nodes, edges, topics, tags, labels (the SoT for the JS layer)
  tutorials.csv       — id, title, url, topic, tags, labels, date (download artifact)
  cooccurrence.csv    — tag pairs and counts (download artifact)

Hard-fails (exit 1 with a file-specific message) on:
  - Front matter missing title / date / description
  - categories[0] not matching any topics.yml `display`
  - A topic in topics.yml with zero tutorials
  - Empty result set

The script is intentionally dependency-free (stdlib only) so it runs under
whatever Python the user / CI has, without a requirements file.
"""
from __future__ import annotations

import csv
import json
import re
import sys
from collections import defaultdict
from datetime import datetime
from itertools import combinations
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TUTORIALS = ROOT / "tutorials"
TOPICS_YAML = ROOT / "_data" / "topics.yml"
ARTIFACTS = ROOT / "artifacts"

SHARED_TAG_THRESHOLD = 2
ALLOWED_LABELS = {
    "beginner", "intermediate", "advanced",
    "case-study", "reference", "methods", "theory",
}

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)

# Cross-cutting mid-level tags. Each tag is added to a tutorial whose
# (title + description + slug) text matches any of the patterns below.
# Inherited verbatim from scripts/build_manifest.py to preserve the
# network's edge structure during the transition. Reviewed before any
# phase that removes build_manifest.py.
MID_LEVEL_TAGS: dict[str, list[str]] = {
    "regression": [r"\bregression\b", r"\bglm\b", r"\bglmm\b", r"\bgam\b",
        r"\blasso\b", r"\bridge\b", r"\belastic net\b", r"\blogistic\b",
        r"\bpoisson regression\b", r"\bquantile regression\b",
        r"\bnegative binomial\b"],
    "hypothesis-testing": [r"\bt[- ]test\b", r"\banova\b", r"\bchi[- ]square\b",
        r"\bchi[- ]squared\b", r"\bhypothesis\b", r"\bsignificance\b",
        r"\bp[- ]value\b", r"\bwilcoxon\b", r"\bmann[- ]whitney\b",
        r"\bkruskal\b", r"\bfriedman\b", r"\bsign test\b", r"\bone[- ]sample\b",
        r"\bgoodness[- ]of[- ]fit\b", r"\bfisher", r"\bmcnemar\b"],
    "non-parametric": [r"\bnon[- ]parametric\b", r"\brank[- ]based\b",
        r"\bwilcoxon\b", r"\bmann[- ]whitney\b", r"\bkruskal\b",
        r"\bfriedman\b", r"\bsign test\b", r"\bspearman\b", r"\bkendall\b",
        r"\bkolmogorov\b", r"\bbootstrap\b", r"\bpermutation test\b"],
    "effect-size": [r"\beffect[- ]size\b", r"\bcohen", r"\bhedges\b",
        r"\bglass\b", r"\bodds ratio\b", r"\brisk ratio\b",
        r"\brelative risk\b", r"\bcliff", r"\beta[- ]squared\b",
        r"\bomega[- ]squared\b"],
    "power-and-sample-size": [r"\bpower\b", r"\bsample[- ]size\b",
        r"\bsample size\b", r"\bsensitivity analysis\b", r"\bnoncentrality\b"],
    "bayesian-methods": [r"\bbayes", r"\bposterior\b", r"\bprior\b",
        r"\bmcmc\b", r"\bgibbs\b", r"\bmetropolis\b", r"\bstan\b",
        r"\bbrms\b", r"\bcredible interval\b", r"\bhpd\b"],
    "categorical-data": [r"\bcontingency\b", r"\bchi[- ]square\b",
        r"\blog[- ]linear\b", r"\bmcnemar\b", r"\bfisher",
        r"\bcategorical\b", r"\bcochran\b", r"\bproportion\b",
        r"\bbinomial\b"],
    "time-to-event": [r"\bsurvival\b", r"\bhazard\b", r"\bkaplan",
        r"\bcox\b", r"\bcensor", r"\baccelerated failure\b",
        r"\bcompeting risk\b", r"\btime[- ]to[- ]event\b", r"\blog[- ]rank\b"],
    "diagnostic-accuracy": [r"\broc\b", r"\bauc\b", r"\bsensitivity\b",
        r"\bspecificity\b", r"\bpredictive value\b", r"\bdiagnostic\b",
        r"\bcutpoint\b", r"\blikelihood ratio\b"],
    "agreement-and-reliability": [r"\bagreement\b", r"\breliability\b",
        r"\bkappa\b", r"\bicc\b", r"\bbland[- ]altman\b", r"\bconcordance\b",
        r"\binter[- ]rater\b", r"\bintra[- ]rater\b"],
    "longitudinal-and-mixed-models": [r"\blongitudinal\b",
        r"\brepeated[- ]measures\b", r"\bmixed[- ]model\b",
        r"\bmixed effects\b", r"\bmultilevel\b", r"\bhierarchical model\b",
        r"\bgee\b", r"\bpanel data\b", r"\bgrowth curve\b"],
    "multivariate-analysis": [r"\bpca\b", r"\bprincipal component\b",
        r"\bfactor analysis\b", r"\bcluster\b", r"\bdiscriminant\b",
        r"\bmanova\b", r"\bmultivariate\b", r"\bcanonical correlation\b",
        r"\bcorrespondence analysis\b", r"\bredundancy\b", r"\bmds\b",
        r"\bnmds\b"],
    "machine-learning-methods": [r"\brandom forest\b", r"\bxgboost\b",
        r"\bgradient boost", r"\bneural\b", r"\bdeep learning\b",
        r"\bclassifier\b", r"\bcross[- ]validation\b", r"\bsvm\b",
        r"\bensemble\b", r"\bregularization\b", r"\bcalibration\b",
        r"\bfeature selection\b", r"\bfeature importance\b"],
    "experimental-design": [r"\brct\b", r"\brandomi[sz]ation\b",
        r"\brandomi[sz]ed\b", r"\bfactorial\b", r"\bblocking\b",
        r"\blatin square\b", r"\bresponse surface\b", r"\bplackett\b",
        r"\btaguchi\b", r"\bdesign of experiments\b", r"\bdoe\b",
        r"\bsplit[- ]plot\b", r"\bcrossover\b"],
    "robust-statistics": [r"\brobust\b", r"\bm[- ]estimator\b",
        r"\btrimmed\b", r"\bwinsoriz", r"\boutlier\b",
        r"\bbreakdown point\b", r"\binfluence function\b"],
    "exploratory-and-descriptive": [r"\bdescriptive\b", r"\bsummary\b",
        r"\bvisuali[sz]ation\b", r"\bexploratory\b", r"\beda\b", r"\bplot\b"],
    "missing-data": [r"\bmissing\b", r"\bimputation\b",
        r"\bcomplete[- ]case\b", r"\bmar\b", r"\bmcar\b", r"\bmnar\b"],
    "meta-analysis-methods": [r"\bmeta[- ]analysis\b", r"\bpooled\b",
        r"\bheterogeneity\b", r"\bforest plot\b", r"\bfunnel\b",
        r"\brandom[- ]effects\b", r"\bfixed[- ]effects\b",
        r"\bnetwork meta\b", r"\bpublication bias\b"],
    "trial-design": [r"\brct\b", r"\btrial\b", r"\bgroup[- ]sequential\b",
        r"\bfutility\b", r"\balpha[- ]spending\b", r"\binterim\b",
        r"\bcrossover\b", r"\bcluster[- ]rct\b", r"\bnon[- ]inferiority\b",
        r"\bequivalence\b", r"\badaptive\b"],
    "omics-and-genomics": [r"\brna[- ]seq\b", r"\bscrna\b",
        r"\bsingle[- ]cell\b", r"\bmicrobiom\b", r"\bmetagenom\b",
        r"\bproteomic\b", r"\btranscriptom\b", r"\bgenom", r"\bgwas\b",
        r"\bvariant call\b", r"\bepigenom\b", r"\bbioinformatic\b"],
    "probability-and-distributions": [r"\bdistribution\b",
        r"\bprobability\b", r"\brandom variable\b", r"\bdensity\b",
        r"\bmoment\b", r"\bquantile\b", r"\bcumulative\b",
        r"\bcharacteristic function\b"],
    "asymptotic-theory": [r"\bcentral limit\b", r"\blaw of large numbers\b",
        r"\bconvergence\b", r"\bdelta method\b", r"\bslutsky\b",
        r"\bglivenko\b", r"\basymptotic\b"],
}
_COMPILED_PATTERNS = {
    tag: [re.compile(p, re.IGNORECASE) for p in patterns]
    for tag, patterns in MID_LEVEL_TAGS.items()
}


def _slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def _derive_mid_tags(title: str, description: str, slug: str) -> list[str]:
    haystack = " ".join([title or "", description or "",
                         slug.replace("/", " ").replace("-", " ")])
    return [tag for tag, regs in _COMPILED_PATTERNS.items()
            if any(r.search(haystack) for r in regs)]


# --------------------------------------------------------------------------- #
# Minimal YAML — only the shapes we actually emit / read.
# We avoid PyYAML to stay dependency-free on cold CI.
# --------------------------------------------------------------------------- #

def parse_topics_yaml(text: str) -> list[dict]:
    """Parse _data/topics.yml. Recognises the documented shape only."""
    topics: list[dict] = []
    current: dict | None = None
    in_topics_list = False
    for raw in text.splitlines():
        line = raw.rstrip()
        # Skip full-line comments only. Stripping inline `#` is unsafe
        # because quoted hex colours like "#1f77b4" contain `#`. Inline
        # comments are not used in topics.yml; if that ever changes, do
        # the strip with quote-awareness.
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        stripped = line
        if stripped.strip() == "topics:":
            in_topics_list = True
            continue
        if not in_topics_list:
            continue
        if stripped.startswith("  - "):
            if current is not None:
                topics.append(current)
            current = {}
            rest = stripped[4:].strip()
            if rest and ":" in rest:
                k, _, v = rest.partition(":")
                current[k.strip()] = _coerce_scalar(v.strip())
            continue
        if stripped.startswith("    ") and current is not None and ":" in stripped:
            k, _, v = stripped.strip().partition(":")
            current[k.strip()] = _coerce_scalar(v.strip())
    if current is not None:
        topics.append(current)
    return topics


def _coerce_scalar(v: str):
    if v == "":
        return ""
    if v.startswith("[") and v.endswith("]"):
        # Inline JSON-style array: ["a", "b"] or ['a', 'b']
        try:
            return json.loads(v.replace("'", '"'))
        except json.JSONDecodeError:
            return v
    if v.startswith('"') and v.endswith('"'):
        return v[1:-1]
    if v.startswith("'") and v.endswith("'"):
        return v[1:-1]
    if v.lstrip("-").isdigit():
        try:
            return int(v)
        except ValueError:
            return v
    return v


def parse_frontmatter(text: str) -> dict:
    """Extract the YAML front matter block. Same minimal grammar as build_manifest.py."""
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}
    body = m.group(1)
    data: dict = {}
    current_key: str | None = None
    current_list: list | None = None
    for raw in body.splitlines():
        line = raw.rstrip()
        if not line:
            continue
        if line.startswith("  - ") or line.startswith("- "):
            value = line.split("-", 1)[1].strip().strip("\"'")
            if current_list is not None:
                current_list.append(value)
            continue
        if ":" in line and not line.startswith(" "):
            key, _, val = line.partition(":")
            key = key.strip()
            val = val.strip()
            current_key = key
            if val == "":
                current_list = []
                data[key] = current_list
            else:
                current_list = None
                data[key] = val.strip("\"'")
    return data


# --------------------------------------------------------------------------- #
# Build pipeline
# --------------------------------------------------------------------------- #

class BuildError(Exception):
    pass


def load_topics() -> tuple[list[dict], dict[str, dict], dict[str, dict]]:
    if not TOPICS_YAML.exists():
        raise BuildError(f"missing {TOPICS_YAML.relative_to(ROOT)} — required SoT")
    topics = parse_topics_yaml(TOPICS_YAML.read_text(encoding="utf-8"))
    if not topics:
        raise BuildError(f"{TOPICS_YAML.relative_to(ROOT)} parsed empty")
    by_slug = {}
    by_display = {}
    for t in topics:
        for k in ("slug", "display", "color", "order"):
            if k not in t:
                raise BuildError(f"topic missing key '{k}': {t!r}")
        by_slug[t["slug"]] = t
        by_display[t["display"]] = t
        for alias in t.get("aliases") or []:
            if alias in by_display:
                raise BuildError(
                    f"alias {alias!r} on topic {t['slug']} collides with "
                    f"display/alias of {by_display[alias]['slug']}"
                )
            by_display[alias] = t
    return topics, by_slug, by_display


def collect_tutorials(by_slug: dict[str, dict], by_display: dict[str, dict]) -> list[dict]:
    nodes: list[dict] = []
    seen_topics_with_tutorials: set[str] = set()

    for qmd in sorted(TUTORIALS.glob("*/*.qmd")):
        if qmd.name == "index.qmd":
            continue
        topic_slug = qmd.parent.name
        if topic_slug not in by_slug:
            raise BuildError(
                f"{qmd.relative_to(ROOT)} lives under unknown topic folder "
                f"'{topic_slug}' (not in _data/topics.yml)"
            )
        topic = by_slug[topic_slug]
        text = qmd.read_text(encoding="utf-8", errors="replace")
        fm = parse_frontmatter(text)

        for required in ("title", "date", "description"):
            if not fm.get(required):
                raise BuildError(
                    f"{qmd.relative_to(ROOT)} missing required front-matter "
                    f"key '{required}'"
                )

        cats = fm.get("categories") or []
        if isinstance(cats, str):
            cats = [cats]
        if not cats:
            raise BuildError(
                f"{qmd.relative_to(ROOT)} has empty 'categories' — "
                f"first entry must be the topic display name"
            )
        # categories[0] must resolve (via display or alias) to the same
        # topic as the folder. Aliases let us keep historical category
        # strings without bulk-editing tutorial front matter.
        resolved = by_display.get(cats[0])
        if resolved is None:
            raise BuildError(
                f"{qmd.relative_to(ROOT)} categories[0]={cats[0]!r} "
                f"does not match any topic display/alias in _data/topics.yml"
            )
        if resolved["slug"] != topic_slug:
            raise BuildError(
                f"{qmd.relative_to(ROOT)} is under folder '{topic_slug}' "
                f"but categories[0]={cats[0]!r} resolves to topic "
                f"'{resolved['slug']}'"
            )

        # Tags = explicit categories[1:], plus a topic-as-tag so same-
        # topic pages cluster, plus regex-derived mid-level tags so
        # methodologically related pages connect across topics. This
        # mirrors the legacy build_manifest.py enrichment so the new
        # graph has the same edges as the old one (parity goal for
        # Phase 2). Phase 6 may revisit which of these surface in chips
        # vs. drive the layout only.
        own_tags = [c for c in cats[1:] if c]
        topic_tag = "topic:" + _slugify(topic["display"])
        slug_id = f"{topic_slug}/{qmd.stem}"
        mid_tags = _derive_mid_tags(fm["title"], fm["description"], slug_id)

        seen_t: set[str] = set()
        enriched_tags: list[str] = []
        for t in [*own_tags, topic_tag, *mid_tags]:
            if t and t not in seen_t:
                seen_t.add(t)
                enriched_tags.append(t)

        labels_raw = fm.get("labels") or []
        if isinstance(labels_raw, str):
            labels_raw = [labels_raw]
        labels = []
        for lab in labels_raw:
            if lab not in ALLOWED_LABELS:
                raise BuildError(
                    f"{qmd.relative_to(ROOT)} has unknown label '{lab}'. "
                    f"Allowed: {sorted(ALLOWED_LABELS)}"
                )
            labels.append(lab)

        date = fm.get("date", "")
        try:
            year = datetime.strptime(date[:10], "%Y-%m-%d").year
        except ValueError:
            raise BuildError(
                f"{qmd.relative_to(ROOT)} has unparseable date {date!r} "
                f"(expected YYYY-MM-DD)"
            )

        nodes.append({
            "id": slug_id,
            "title": fm["title"],
            "url": f"tutorials/{topic_slug}/{qmd.stem}.html",
            "topic": topic_slug,
            "tags": enriched_tags,
            "labels": labels,
            "date": date[:10],
            "year": year,
            "summary": fm["description"],
        })
        seen_topics_with_tutorials.add(topic_slug)

    if not nodes:
        raise BuildError("no tutorials found under tutorials/*/*.qmd")

    missing = set(by_slug) - seen_topics_with_tutorials
    if missing:
        raise BuildError(
            f"topics in _data/topics.yml with zero tutorials: "
            f"{sorted(missing)}"
        )

    return nodes


def compute_edges(nodes: list[dict]) -> list[dict]:
    """Edge iff ≥ SHARED_TAG_THRESHOLD shared tags. Weight = shared count.

    Uses an inverted tag→nodes index to avoid O(n²) over all pairs.
    """
    tag_to_nodes: dict[str, list[int]] = defaultdict(list)
    for i, n in enumerate(nodes):
        for tag in n["tags"]:
            tag_to_nodes[tag].append(i)

    pair_count: dict[tuple[int, int], int] = defaultdict(int)
    for nodes_with_tag in tag_to_nodes.values():
        if len(nodes_with_tag) < 2:
            continue
        for i, j in combinations(nodes_with_tag, 2):
            pair_count[(i, j)] += 1

    edges = []
    for (i, j), w in pair_count.items():
        if w >= SHARED_TAG_THRESHOLD:
            edges.append({
                "source": nodes[i]["id"],
                "target": nodes[j]["id"],
                "weight": w,
            })
    return edges


def compute_facets(nodes: list[dict], topics: list[dict]) -> dict:
    topic_count = defaultdict(int)
    tag_count = defaultdict(int)
    label_count = defaultdict(int)
    for n in nodes:
        topic_count[n["topic"]] += 1
        for t in n["tags"]:
            tag_count[t] += 1
        for lab in n["labels"]:
            label_count[lab] += 1
    return {
        "topics": [
            {
                "id": t["slug"],
                "label": t["display"],
                "color": t["color"],
                "blurb": t.get("blurb", ""),
                "order": t["order"],
                "count": topic_count[t["slug"]],
            }
            for t in sorted(topics, key=lambda x: x["order"])
        ],
        "tags": [
            {"id": k, "label": k, "count": v}
            for k, v in sorted(tag_count.items(), key=lambda kv: (-kv[1], kv[0]))
        ],
        "labels": [
            {"id": k, "label": k, "count": v}
            for k, v in sorted(label_count.items(), key=lambda kv: (-kv[1], kv[0]))
        ],
    }


def cooccurrence(nodes: list[dict]) -> list[tuple[str, str, int]]:
    pair_count: dict[tuple[str, str], int] = defaultdict(int)
    for n in nodes:
        for a, b in combinations(sorted(set(n["tags"])), 2):
            pair_count[(a, b)] += 1
    return [(a, b, c) for (a, b), c in sorted(pair_count.items(), key=lambda x: -x[1])]


# --------------------------------------------------------------------------- #
# Writers
# --------------------------------------------------------------------------- #

def write_graph_json(nodes, edges, facets):
    out = ARTIFACTS / "graph.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "nodes": nodes,
        "edges": edges,
        "topics": facets["topics"],
        "tags": facets["tags"],
        "labels": facets["labels"],
    }
    out.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    return out


def write_tutorials_csv(nodes):
    out = ARTIFACTS / "tutorials.csv"
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["id", "title", "url", "topic", "tags", "labels", "date"])
        for n in nodes:
            w.writerow([
                n["id"], n["title"], n["url"], n["topic"],
                "|".join(n["tags"]), "|".join(n["labels"]), n["date"],
            ])
    return out


def write_cooccurrence_csv(rows):
    out = ARTIFACTS / "cooccurrence.csv"
    with out.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["tag_a", "tag_b", "count"])
        for a, b, c in rows:
            w.writerow([a, b, c])
    return out


# --------------------------------------------------------------------------- #
# Entry point
# --------------------------------------------------------------------------- #

def main() -> int:
    try:
        topics, by_slug, by_display = load_topics()
        nodes = collect_tutorials(by_slug, by_display)
        edges = compute_edges(nodes)
        if not edges:
            raise BuildError("computed graph has zero edges — tag overlap broke")
        facets = compute_facets(nodes, topics)
        co = cooccurrence(nodes)

        graph_path = write_graph_json(nodes, edges, facets)
        write_tutorials_csv(nodes)
        write_cooccurrence_csv(co)

        print(
            f"build_graph: {len(nodes)} nodes, {len(edges)} edges, "
            f"{len(facets['topics'])} topics, {len(facets['tags'])} tags, "
            f"{len(facets['labels'])} labels -> {graph_path.relative_to(ROOT)}"
        )
        return 0
    except BuildError as e:
        print(f"build_graph: ERROR — {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
