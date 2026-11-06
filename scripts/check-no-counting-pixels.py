#!/usr/bin/env python3
"""Reject counting-pixel endpoints and metadata in publication sources and output."""
from pathlib import Path
import re
import sys
PATTERN = re.compile(r'(?:[\w.-]+\.)?met\.' + r'vgwort\.de|vgwort[-_]pixel\s*:', re.I)
EXTENSIONS = {'.html', '.htm', '.js', '.css', '.lua', '.yml', '.yaml', '.qmd', '.rmd', '.md', '.csv', '.json', '.xml', '.r'}
EXCLUDED = {'.git', 'node_modules', 'renv', '.venv', '_freeze', '.quarto'}
def scan(root):
    failures = []
    for path in root.rglob('*'):
        if not path.is_file() or path.suffix.lower() not in EXTENSIONS or EXCLUDED.intersection(path.relative_to(root).parts):
            continue
        for number, line in enumerate(path.read_text(errors='replace').splitlines(), 1):
            if PATTERN.search(line): failures.append(f'{path}:{number}')
    return failures
if __name__ == '__main__':
    failures = [item for root in (Path(p) for p in (sys.argv[1:] or ['.'])) for item in scan(root)]
    if failures:
        print('Counting-pixel references found:\n' + '\n'.join(failures)); sys.exit(1)
    print('No counting-pixel endpoints or metadata found.')
