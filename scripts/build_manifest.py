"""Build js/tutorials-manifest.json from tutorials/**/*.qmd frontmatter.

Each entry: {slug, url, title, description, topic, topic_slug, tags, difficulty}.
Tags are an enriched superset:
  1. The page's own categories (with the topic display-name filtered out).
  2. The topic itself, slugified — so same-topic pages cluster in the
     network even when their categories don't overlap.
  3. Cross-cutting mid-level tags (regression, hypothesis-testing,
     non-parametric, time-to-event, ...) derived by keyword patterns on
     the title, description and slug. These produce meaningful edges
     across topic areas in the tag-similarity graph.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TUTORIALS = ROOT / "tutorials"
OUT = ROOT / "js" / "tutorials-manifest.json"

TOPIC_NAMES = {
    "statistical-foundations": "Statistical Foundations",
    "descriptive-statistics": "Descriptive Statistics",
    "probability": "Probability Theory",
    "inference": "Inferential Statistics",
    "sample-size": "Sample Size & Power",
    "visualisation": "Data Visualisation",
    "regression-modelling": "Regression & Modelling",
    "multivariate": "Multivariate Methods",
    "time-series": "Time-Series Analysis",
    "bayesian": "Bayesian Statistics",
    "survival-analysis": "Survival Analysis",
    "bioinformatics": "Bioinformatics",
    "machine-learning": "Machine Learning",
    "clinical-biostatistics": "Clinical Biostatistics",
    "meta-analysis": "Meta-Analysis",
    "experimental-design": "Experimental Design",
}

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)

# Cross-cutting mid-level tags. Each tag is added to a tutorial whose
# (title + description + slug) text matches any of the patterns below.
# Patterns are applied case-insensitively against text with hyphens
# normalised to spaces.
MID_LEVEL_TAGS: dict[str, list[str]] = {
    "regression": [
        r"\bregression\b", r"\bglm\b", r"\bglmm\b", r"\bgam\b",
        r"\blasso\b", r"\bridge\b", r"\belastic net\b",
        r"\blogistic\b", r"\bpoisson regression\b",
        r"\bquantile regression\b", r"\bnegative binomial\b",
    ],
    "hypothesis-testing": [
        r"\bt[- ]test\b", r"\banova\b", r"\bchi[- ]square\b", r"\bchi[- ]squared\b",
        r"\bhypothesis\b", r"\bsignificance\b", r"\bp[- ]value\b",
        r"\bwilcoxon\b", r"\bmann[- ]whitney\b", r"\bkruskal\b",
        r"\bfriedman\b", r"\bsign test\b", r"\bone[- ]sample\b",
        r"\bgoodness[- ]of[- ]fit\b", r"\bfisher", r"\bmcnemar\b",
    ],
    "non-parametric": [
        r"\bnon[- ]parametric\b", r"\brank[- ]based\b", r"\bwilcoxon\b",
        r"\bmann[- ]whitney\b", r"\bkruskal\b", r"\bfriedman\b",
        r"\bsign test\b", r"\bspearman\b", r"\bkendall\b",
        r"\bkolmogorov\b", r"\bbootstrap\b", r"\bpermutation test\b",
    ],
    "effect-size": [
        r"\beffect[- ]size\b", r"\bcohen", r"\bhedges\b", r"\bglass\b",
        r"\bodds ratio\b", r"\brisk ratio\b", r"\brelative risk\b",
        r"\bcliff", r"\beta[- ]squared\b", r"\bomega[- ]squared\b",
    ],
    "power-and-sample-size": [
        r"\bpower\b", r"\bsample[- ]size\b", r"\bsample size\b",
        r"\bsensitivity analysis\b", r"\bnoncentrality\b",
    ],
    "bayesian-methods": [
        r"\bbayes", r"\bposterior\b", r"\bprior\b", r"\bmcmc\b",
        r"\bgibbs\b", r"\bmetropolis\b", r"\bstan\b", r"\bbrms\b",
        r"\bcredible interval\b", r"\bhpd\b",
    ],
    "categorical-data": [
        r"\bcontingency\b", r"\bchi[- ]square\b", r"\blog[- ]linear\b",
        r"\bmcnemar\b", r"\bfisher", r"\bcategorical\b",
        r"\bcochran\b", r"\bproportion\b", r"\bbinomial\b",
    ],
    "time-to-event": [
        r"\bsurvival\b", r"\bhazard\b", r"\bkaplan", r"\bcox\b",
        r"\bcensor", r"\baccelerated failure\b", r"\bcompeting risk\b",
        r"\btime[- ]to[- ]event\b", r"\blog[- ]rank\b",
    ],
    "diagnostic-accuracy": [
        r"\broc\b", r"\bauc\b", r"\bsensitivity\b", r"\bspecificity\b",
        r"\bpredictive value\b", r"\bdiagnostic\b", r"\bcutpoint\b",
        r"\blikelihood ratio\b",
    ],
    "agreement-and-reliability": [
        r"\bagreement\b", r"\breliability\b", r"\bkappa\b", r"\bicc\b",
        r"\bbland[- ]altman\b", r"\bconcordance\b",
        r"\binter[- ]rater\b", r"\bintra[- ]rater\b",
    ],
    "longitudinal-and-mixed-models": [
        r"\blongitudinal\b", r"\brepeated[- ]measures\b",
        r"\bmixed[- ]model\b", r"\bmixed effects\b",
        r"\bmultilevel\b", r"\bhierarchical model\b",
        r"\bgee\b", r"\bpanel data\b", r"\bgrowth curve\b",
    ],
    "multivariate-analysis": [
        r"\bpca\b", r"\bprincipal component\b", r"\bfactor analysis\b",
        r"\bcluster\b", r"\bdiscriminant\b", r"\bmanova\b",
        r"\bmultivariate\b", r"\bcanonical correlation\b",
        r"\bcorrespondence analysis\b", r"\bredundancy\b",
        r"\bmds\b", r"\bnmds\b",
    ],
    "machine-learning-methods": [
        r"\brandom forest\b", r"\bxgboost\b", r"\bgradient boost",
        r"\bneural\b", r"\bdeep learning\b", r"\bclassifier\b",
        r"\bcross[- ]validation\b", r"\bsvm\b", r"\bensemble\b",
        r"\bregularization\b", r"\bcalibration\b",
        r"\bfeature selection\b", r"\bfeature importance\b",
    ],
    "experimental-design": [
        r"\brct\b", r"\brandomi[sz]ation\b", r"\brandomi[sz]ed\b",
        r"\bfactorial\b", r"\bblocking\b", r"\blatin square\b",
        r"\bresponse surface\b", r"\bplackett\b", r"\btaguchi\b",
        r"\bdesign of experiments\b", r"\bdoe\b",
        r"\bsplit[- ]plot\b", r"\bcrossover\b",
    ],
    "robust-statistics": [
        r"\brobust\b", r"\bm[- ]estimator\b", r"\btrimmed\b",
        r"\bwinsoriz", r"\boutlier\b", r"\bbreakdown point\b",
        r"\binfluence function\b",
    ],
    "exploratory-and-descriptive": [
        r"\bdescriptive\b", r"\bsummary\b", r"\bvisuali[sz]ation\b",
        r"\bexploratory\b", r"\beda\b", r"\bplot\b",
    ],
    "missing-data": [
        r"\bmissing\b", r"\bimputation\b", r"\bcomplete[- ]case\b",
        r"\bmar\b", r"\bmcar\b", r"\bmnar\b",
    ],
    "meta-analysis-methods": [
        r"\bmeta[- ]analysis\b", r"\bpooled\b", r"\bheterogeneity\b",
        r"\bforest plot\b", r"\bfunnel\b", r"\brandom[- ]effects\b",
        r"\bfixed[- ]effects\b", r"\bnetwork meta\b",
        r"\bpublication bias\b",
    ],
    "trial-design": [
        r"\brct\b", r"\btrial\b", r"\bgroup[- ]sequential\b",
        r"\bfutility\b", r"\balpha[- ]spending\b", r"\binterim\b",
        r"\bcrossover\b", r"\bcluster[- ]rct\b",
        r"\bnon[- ]inferiority\b", r"\bequivalence\b", r"\badaptive\b",
    ],
    "omics-and-genomics": [
        r"\brna[- ]seq\b", r"\bscrna\b", r"\bsingle[- ]cell\b",
        r"\bmicrobiom\b", r"\bmetagenom\b", r"\bproteomic\b",
        r"\btranscriptom\b", r"\bgenom", r"\bgwas\b",
        r"\bvariant call\b", r"\bepigenom\b", r"\bbioinformatic\b",
    ],
    "probability-and-distributions": [
        r"\bdistribution\b", r"\bprobability\b", r"\brandom variable\b",
        r"\bdensity\b", r"\bmoment\b", r"\bquantile\b",
        r"\bcumulative\b", r"\bcharacteristic function\b",
    ],
    "asymptotic-theory": [
        r"\bcentral limit\b", r"\blaw of large numbers\b",
        r"\bconvergence\b", r"\bdelta method\b", r"\bslutsky\b",
        r"\bglivenko\b", r"\basymptotic\b",
    ],
}

_COMPILED_PATTERNS = {
    tag: [re.compile(p, re.IGNORECASE) for p in patterns]
    for tag, patterns in MID_LEVEL_TAGS.items()
}


def slugify_topic(topic: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", topic.lower()).strip("-")


def derive_mid_level_tags(title: str, description: str, slug: str) -> list[str]:
    """Match a tutorial against the cross-cutting tag patterns."""
    haystack = " ".join([title or "", description or "", slug.replace("/", " ").replace("-", " ")])
    out = []
    for tag, regexes in _COMPILED_PATTERNS.items():
        if any(rgx.search(haystack) for rgx in regexes):
            out.append(tag)
    return out


def parse_frontmatter(text: str) -> dict:
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
            value = line.split("-", 1)[1].strip()
            value = value.strip("\"'")
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


def main() -> int:
    entries = []
    for qmd in sorted(TUTORIALS.glob("*/*.qmd")):
        if qmd.name == "index.qmd":
            continue
        topic_slug = qmd.parent.name
        topic = TOPIC_NAMES.get(topic_slug, topic_slug)
        text = qmd.read_text(encoding="utf-8", errors="replace")
        fm = parse_frontmatter(text)
        title = fm.get("title", qmd.stem)
        description = fm.get("description", "")
        difficulty = fm.get("difficulty", "")
        cats = fm.get("categories") or []
        if isinstance(cats, str):
            cats = [cats]
        # Drop the human-readable topic name from tags; keep the rest.
        topic_aliases = {
            topic,
            *TOPIC_NAMES.values(),
            "Multivariate Statistics",
            "Time Series Analysis",
            "Time-Series",
            "Sample Size and Power",
        }
        own_tags = [c for c in cats if c and c not in topic_aliases]

        rel_url = f"tutorials/{topic_slug}/{qmd.stem}.html"
        slug = f"{topic_slug}/{qmd.stem}"

        # Topic-as-tag (slugified) so same-topic pages cluster in the network.
        topic_tag = "topic:" + slugify_topic(topic)

        # Cross-cutting mid-level tags from keyword patterns.
        mid = derive_mid_level_tags(title, description, slug)

        # Preserve order, drop duplicates.
        seen: set[str] = set()
        tags: list[str] = []
        for t in [*own_tags, topic_tag, *mid]:
            if t in seen:
                continue
            seen.add(t)
            tags.append(t)

        entries.append({
            "slug": slug,
            "url": rel_url,
            "title": title,
            "description": description,
            "topic": topic,
            "topic_slug": topic_slug,
            "tags": tags,
            "difficulty": difficulty,
        })

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"tutorials": entries}, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Wrote {len(entries)} entries to {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
