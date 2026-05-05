#!/usr/bin/env python3
"""Build index.qmd (home) and tutorials.qmd (full index) from converted .qmd files."""

from __future__ import annotations
import re
from pathlib import Path


CATEGORIES_ORDER = [
    ("statistical-foundations", "Statistical Foundations",
     "Foundational concepts: probability, sampling, inference framework."),
    ("descriptive-statistics", "Descriptive Statistics",
     "Summarising and exploring data before modelling."),
    ("probability", "Probability Theory",
     "Axioms, distributions, expectations, and the algebra of random variables."),
    ("inference", "Inferential Statistics",
     "Hypothesis tests, confidence intervals, and the logic of inference."),
    ("sample-size", "Sample Size & Power",
     "Planning studies with adequate statistical power."),
    ("visualisation", "Data Visualisation",
     "Publication-quality graphics with ggplot2 and friends."),
    ("regression-modelling", "Regression & Modelling",
     "Linear models, GLMs, mixed models, and beyond."),
    ("multivariate", "Multivariate Methods",
     "PCA, clustering, factor analysis, discriminant analysis."),
    ("time-series", "Time-Series Analysis",
     "ARIMA, state-space, spectral, and forecasting methods."),
    ("bayesian", "Bayesian Statistics",
     "Bayesian inference, MCMC, and probabilistic programming."),
    ("survival-analysis", "Survival Analysis",
     "Censored time-to-event data: Kaplan-Meier, Cox, AFT, competing risks."),
    ("bioinformatics", "Bioinformatics",
     "Genomics pipelines from FASTQ to differential expression and beyond."),
    ("machine-learning", "Machine Learning",
     "Tree ensembles, neural networks, calibration, interpretability."),
    ("clinical-biostatistics", "Clinical Biostatistics",
     "RCT design, adaptive trials, diagnostic accuracy, agreement."),
    ("meta-analysis", "Meta-Analysis",
     "Effect-size pooling, heterogeneity, bias, network meta-analysis."),
    ("experimental-design", "Experimental Design",
     "Factorials, response surfaces, mixture designs, robust design."),
]


FRONTMATTER = re.compile(r'^---\n(.*?)\n---\n', re.DOTALL)


def parse_qmd(path: Path) -> dict:
    """Return dict with title, date, description, slug, path."""
    text = path.read_text(encoding='utf-8')
    m = FRONTMATTER.match(text)
    fm = {}
    if m:
        for line in m.group(1).splitlines():
            if ':' not in line:
                continue
            k, _, v = line.partition(':')
            k = k.strip()
            v = v.strip().strip('"')
            if k in ('title', 'date', 'description'):
                fm[k] = v
    fm['path'] = str(path)
    fm['slug'] = path.stem
    return fm


def list_tutorials_by_category():
    out = {}
    for slug, _, _ in CATEGORIES_ORDER:
        d = Path('tutorials') / slug
        if not d.is_dir():
            continue
        files = [p for p in d.glob('*.qmd') if p.stem != 'index']
        items = [parse_qmd(p) for p in files]
        items.sort(key=lambda m: m.get('title', ''))
        out[slug] = items
    return out


def emit_home():
    lines = [
        '---',
        'title: "Statistics & Bioinformatics Tutorials"',
        'description: "Comprehensive tutorials in statistics and bioinformatics with R"',
        'toc: false',
        '---',
        '',
        '::: {.hero}',
        '::: {.kicker}',
        'TUTORIALS · 569 PAGES · SIXTEEN TOPIC AREAS',
        ':::',
        '# Statistics &amp; Bioinformatics Tutorials',
        '::: {.lead}',
        'Comprehensive tutorials covering probability, inference, regression, '
        'Bayesian statistics, survival analysis, bioinformatics, and machine '
        'learning, with runnable R examples throughout.',
        ':::',
        ':::',
        '',
        '## Explore by topic',
        '',
        '::: {.card-grid}',
        '',
    ]
    for slug, name, tagline in CATEGORIES_ORDER:
        d = Path('tutorials') / slug
        if not d.is_dir():
            continue
        count = len([p for p in d.glob('*.qmd') if p.stem != 'index'])
        lines.extend([
            '::: {.card}',
            '::: {.kicker}',
            f'{count} TUTORIALS',
            ':::',
            f'### [{name}](tutorials/{slug}/index.qmd)',
            tagline,
            ':::',
            '',
        ])
    lines.extend([
        ':::',
        '',
        '## Other sections',
        '',
        '::: {.card-grid}',
        '',
        '::: {.card}',
        '::: {.kicker}',
        'INTERACTIVE',
        ':::',
        '### [Decision Tree](decision-tree/index.qmd)',
        'Interactive wizard and static chart guiding the choice of statistical test.',
        ':::',
        '',
        '::: {.card}',
        '::: {.kicker}',
        'APPS',
        ':::',
        '### [Shiny Apps](shiny/index.qmd)',
        'Sixteen interactive Shiny applications, one per topic area.',
        ':::',
        '',
        ':::',
        '',
        '[Browse all tutorials &rarr;](tutorials.qmd)',
        '',
    ])
    Path('index.qmd').write_text('\n'.join(lines), encoding='utf-8')


def emit_tutorials_index(cats):
    lines = [
        '---',
        'title: "All Tutorials"',
        'description: "Complete index of every tutorial, grouped by topic area."',
        '---',
        '',
        '::: {.hero}',
        '::: {.kicker}',
        'INDEX',
        ':::',
        '# All tutorials',
        '::: {.lead}',
        'Every tutorial on the site, grouped by topic. Use the links below '
        'to jump to a topic landing page or directly to an individual '
        'tutorial.',
        ':::',
        ':::',
        '',
    ]
    for slug, name, _ in CATEGORIES_ORDER:
        items = cats.get(slug, [])
        if not items:
            continue
        lines.append(f'## [{name}](tutorials/{slug}/index.qmd)')
        lines.append('')
        for it in items:
            title = it.get('title') or it['slug']
            desc = it.get('description') or ''
            if desc:
                lines.append(f'- [**{title}**](tutorials/{slug}/{it["slug"]}.qmd) -- {desc}')
            else:
                lines.append(f'- [**{title}**](tutorials/{slug}/{it["slug"]}.qmd)')
        lines.append('')
    Path('tutorials.qmd').write_text('\n'.join(lines), encoding='utf-8')


def emit_category_indexes(cats):
    """Augment each tutorials/<cat>/index.qmd with a card grid of its tutorials."""
    for slug, name, _ in CATEGORIES_ORDER:
        idx = Path('tutorials') / slug / 'index.qmd'
        if not idx.exists():
            continue
        items = cats.get(slug, [])
        # Append a card grid after existing content
        body = idx.read_text(encoding='utf-8')
        if '<!-- card-grid-injected -->' in body:
            continue  # idempotent
        grid = ['', '<!-- card-grid-injected -->', '', '## Tutorials', '',
                '::: {.card-grid}', '']
        for it in items:
            title = it.get('title') or it['slug']
            desc = (it.get('description') or '').strip()
            grid.append('::: {.card}')
            if desc:
                grid.append('::: {.kicker}')
                grid.append('TUTORIAL')
                grid.append(':::')
            grid.append(f'### [{title}]({it["slug"]}.qmd)')
            if desc:
                grid.append(desc)
            grid.append(':::')
            grid.append('')
        grid.append(':::')
        grid.append('')
        idx.write_text(body.rstrip() + '\n' + '\n'.join(grid), encoding='utf-8')


def emit_decision_tree_index():
    p = Path('decision-tree/index.qmd')
    if not p.exists():
        return
    body = p.read_text(encoding='utf-8')
    if '<!-- card-grid-injected -->' in body:
        return
    grid_items = []
    for sub in ['foundations', 'differences', 'associations', 'interdependence']:
        d = Path('decision-tree') / sub
        if not d.is_dir():
            continue
        idx = d / 'index.qmd'
        sub_title = sub.capitalize()
        if idx.exists():
            fm = parse_qmd(idx)
            sub_title = fm.get('title', sub_title)
        grid_items.append((sub_title, f'{sub}/index.qmd',
                           f'{len([p for p in d.glob("*.qmd") if p.stem != "index"])} pages'))
    extras = [
        ('Interactive Wizard', 'decision-assistant.qmd',
         'Answer a few questions and be routed to the appropriate test.'),
        ('Static Decision Tree', 'decision-tree.qmd',
         'Visual Mermaid chart of the same routing logic.'),
    ]
    grid = ['', '<!-- card-grid-injected -->', '', '## Sections', '',
            '::: {.card-grid}', '']
    for t, href, meta in grid_items:
        grid.extend([
            '::: {.card}',
            '::: {.kicker}', meta, ':::',
            f'### [{t}]({href})',
            ':::',
            '',
        ])
    for t, href, desc in extras:
        grid.extend([
            '::: {.card}',
            '::: {.kicker}', 'TOOL', ':::',
            f'### [{t}]({href})',
            desc,
            ':::',
            '',
        ])
    grid.append(':::')
    grid.append('')
    p.write_text(body.rstrip() + '\n' + '\n'.join(grid), encoding='utf-8')


def emit_shiny_index():
    p = Path('shiny/index.qmd')
    if not p.exists():
        return
    body = p.read_text(encoding='utf-8')
    if '<!-- card-grid-injected -->' in body:
        return
    items = sorted([f for f in Path('shiny').glob('*.qmd')
                     if f.stem != 'index'])
    grid = ['', '<!-- card-grid-injected -->', '', '## Apps', '',
            '::: {.card-grid}', '']
    for it in items:
        fm = parse_qmd(it)
        title = fm.get('title', it.stem)
        desc = fm.get('description', '')
        grid.extend([
            '::: {.card}',
            '::: {.kicker}', 'SHINY APP', ':::',
            f'### [{title}]({it.name})',
        ])
        if desc:
            grid.append(desc)
        grid.extend([':::', ''])
    grid.append(':::')
    grid.append('')
    p.write_text(body.rstrip() + '\n' + '\n'.join(grid), encoding='utf-8')


def main():
    cats = list_tutorials_by_category()
    emit_home()
    emit_tutorials_index(cats)
    emit_category_indexes(cats)
    emit_decision_tree_index()
    emit_shiny_index()
    total = sum(len(v) for v in cats.values())
    print(f'wrote index.qmd, tutorials.qmd, {len(cats)} category indexes, '
          f'decision-tree index, shiny index ({total} tutorials cataloged)')


if __name__ == '__main__':
    main()
