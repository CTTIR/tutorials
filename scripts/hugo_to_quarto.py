#!/usr/bin/env python3
"""
Convert Hugo .md (TOML frontmatter + shortcodes) into Quarto .qmd
(YAML frontmatter + standard Markdown).

One-shot, idempotent-enough for the tutorials repo:
- content/_index.md        -> index.qmd
- content/about.md         -> about.qmd
- content/tutorials/<cat>/_index.md     -> tutorials/<cat>/index.qmd
- content/tutorials/<cat>/<slug>.md     -> tutorials/<cat>/<slug>.qmd
- content/decision-tree/...             -> decision-tree/...
- content/shiny/NN-<name>.md            -> shiny/NN-<name>.qmd

Transformations applied to each body:
- {{< mermaid >}}...{{< /mermaid >}}  -> ```{mermaid} ... ```
- {{< wizard >}}                      -> raw HTML wizard mount point
- site-relative Hugo links /tutorials/<cat>/<slug>/ -> ../<cat>/<slug>.qmd

Frontmatter rules:
- Keep: title, date, description, categories, tags
- Drop: difficulty, series, packages, status, toc, weight
"""

from __future__ import annotations
import os
import re
import sys
from pathlib import Path


# --- TOML frontmatter parsing (dependency-free; the repo uses a tiny subset) -------

TOML_DELIM = re.compile(r'^\+\+\+\s*$', re.M)

def parse_toml_frontmatter(text: str):
    """Return (frontmatter_dict, body). Falls back to ({}, text) if no frontmatter."""
    if not text.startswith('+++'):
        return {}, text
    parts = text.split('+++', 2)
    if len(parts) < 3:
        return {}, text
    _, front, body = parts
    data = {}
    # naive TOML parser: handles scalars and simple string arrays, no nested tables
    for line in front.splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if '=' not in line:
            continue
        key, _, val = line.partition('=')
        key = key.strip()
        val = val.strip()
        if val.startswith('[') and val.endswith(']'):
            inner = val[1:-1].strip()
            items = []
            if inner:
                # split on commas not inside quotes
                cur = ''
                in_q = False
                for ch in inner + ',':
                    if ch == '"':
                        in_q = not in_q
                        cur += ch
                    elif ch == ',' and not in_q:
                        items.append(cur.strip())
                        cur = ''
                    else:
                        cur += ch
            items = [x.strip().strip('"') for x in items if x.strip()]
            data[key] = items
        elif val.startswith('"') and val.endswith('"'):
            data[key] = val[1:-1]
        elif val.lower() in ('true', 'false'):
            data[key] = (val.lower() == 'true')
        else:
            # dates look like 2026-04-17
            data[key] = val
    return data, body.lstrip('\n')


def yaml_escape(s: str) -> str:
    """Quote a scalar for YAML; naive but sufficient for our titles/descriptions."""
    if s is None:
        return ''
    needs_quote = any(c in s for c in ':#\'"`&*|>{}[],!%@?') or s.strip() != s
    if needs_quote:
        return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
    return s


def write_yaml_frontmatter(fm: dict) -> str:
    """Emit a minimal YAML frontmatter from our whitelist of keys."""
    out = ['---']
    if 'title' in fm:
        out.append(f'title: {yaml_escape(fm["title"])}')
    if 'date' in fm:
        out.append(f'date: "{fm["date"]}"')
    if 'description' in fm:
        out.append(f'description: {yaml_escape(fm["description"])}')
    cats = fm.get('categories') or []
    tags = fm.get('tags') or []
    merged = [c for c in (list(cats) + list(tags)) if c]
    if merged:
        out.append('categories:')
        for c in merged:
            out.append(f'  - {yaml_escape(c)}')
    # carry through any author if present
    if 'author' in fm:
        out.append(f'author: {yaml_escape(fm["author"])}')
    out.append('---')
    return '\n'.join(out) + '\n\n'


# --- body transforms ---------------------------------------------------------------

MERMAID_BLOCK = re.compile(r'\{\{<\s*mermaid\s*>\}\}(.*?)\{\{<\s*/mermaid\s*>\}\}',
                            re.DOTALL)

def convert_mermaid(body: str) -> str:
    def repl(m):
        inner = m.group(1).strip('\n')
        return '```{mermaid}\n' + inner + '\n```'
    return MERMAID_BLOCK.sub(repl, body)


WIZARD_TAG = re.compile(r'\{\{<\s*wizard\s*>\}\}')

WIZARD_HTML = """```{=html}
<div id="wizard-root" role="application" aria-label="Statistical test decision assistant">
  <noscript>
    <div class="wizard-noscript">
      <p><strong>JavaScript is required</strong> for the interactive wizard.
      Use the <a href="../decision-tree.html">static decision tree</a>
      instead.</p>
    </div>
  </noscript>
</div>
<link rel="stylesheet" href="../css/wizard.css">
<script src="../js/wizard.js" defer></script>
```
"""

def convert_wizard(body: str) -> str:
    return WIZARD_TAG.sub(WIZARD_HTML, body)


# Hugo site-relative links that the tutorials sometimes use: [text](/tutorials/cat/slug/)
# Convert to Quarto relative links. Since we flatten to tutorials/<cat>/<slug>.qmd,
# inside a tutorial the relative link to another cat is ../<other>/slug.qmd and to
# same cat is ./slug.qmd. We'll keep it simple and emit a root-relative URL that
# Quarto can resolve.
HUGO_SITE_LINK = re.compile(r'\(/tutorials/([^)\s]+?)/?\)')

def convert_internal_links(body: str) -> str:
    def repl(m):
        path = m.group(1).rstrip('/')
        return f'(/tutorials/{path}.qmd)'
    return HUGO_SITE_LINK.sub(repl, body)


DECISION_SITE_LINK = re.compile(r'\(/decision-tree/([^)\s]+?)/?\)')
def convert_decision_links(body: str) -> str:
    def repl(m):
        path = m.group(1).rstrip('/')
        return f'(/decision-tree/{path}.qmd)'
    return DECISION_SITE_LINK.sub(repl, body)


def body_transform(body: str) -> str:
    body = convert_mermaid(body)
    body = convert_wizard(body)
    body = convert_internal_links(body)
    body = convert_decision_links(body)
    return body


# --- path mapping ------------------------------------------------------------------

def map_path(src: Path, repo_root: Path) -> Path | None:
    rel = src.relative_to(repo_root)
    parts = rel.parts
    if parts[0] != 'content':
        return None
    rest = parts[1:]
    if not rest:
        return None
    # content/_index.md -> index.qmd
    if rest == ('_index.md',):
        return repo_root / 'index.qmd'
    # content/about.md  -> about.qmd
    if rest == ('about.md',):
        return repo_root / 'about.qmd'
    # content/<section>/_index.md -> <section>/index.qmd
    # content/<section>/<sub>/_index.md -> <section>/<sub>/index.qmd
    # content/<section>/.../<file>.md -> <section>/.../<file>.qmd
    if rest[-1] == '_index.md':
        new_parts = list(rest[:-1]) + ['index.qmd']
    else:
        new_parts = list(rest[:-1]) + [rest[-1][:-3] + '.qmd']
    return repo_root / Path(*new_parts)


# --- main ---------------------------------------------------------------------------

def convert_file(src: Path, dst: Path) -> str:
    """Convert src (.md) to dst (.qmd). Returns a status string."""
    text = src.read_text(encoding='utf-8')
    fm, body = parse_toml_frontmatter(text)
    body = body_transform(body)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out = write_yaml_frontmatter(fm) + body
    # ensure trailing newline
    if not out.endswith('\n'):
        out += '\n'
    dst.write_text(out, encoding='utf-8')
    return 'OK'


def main():
    repo_root = Path('.').resolve()
    sources = sorted(Path('content').rglob('*.md'))
    ok = todo = skipped = 0
    for src in sources:
        dst = map_path(src.resolve(), repo_root)
        if dst is None:
            print(f'SKIP {src}: no mapping')
            skipped += 1
            continue
        try:
            status = convert_file(src, dst)
            rel_src = src
            rel_dst = dst.relative_to(repo_root)
            print(f'{status} {rel_src} -> {rel_dst}')
            ok += 1
        except Exception as e:  # noqa: BLE001
            print(f'TODO {src}: {e}')
            todo += 1
    print()
    print(f'Summary: {ok} converted, {todo} flagged TODO, {skipped} skipped')


if __name__ == '__main__':
    main()
