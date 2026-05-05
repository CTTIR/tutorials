# `distribute_vgwort.py` — usage

Distributes VG Wort Zählmarken from the shared xlsx inventory into eligible
`.qmd` pages of this Quarto site. One marker per page; idempotent; atomic.

## The shared inventory

```
F:\Dropbox\Arbeit\Firma\boulingua\VGWort - rh\zaehlmarken_combined.xlsx
```

This file is **shared across `tutorials/`, `courses/`, and any other repo**.
Run the script in one repo, commit, then run in the next — that's the
intended workflow.

## Order of operations (PowerShell)

1. Make sure the working tree is clean:
   ```powershell
   git status
   ```

2. Dry-run against a small slice first (recommended for first run in a repo):
   ```powershell
   python scripts/distribute_vgwort.py `
       --xlsx "F:\Dropbox\Arbeit\Firma\boulingua\VGWort - rh\zaehlmarken_combined.xlsx" `
       --only "tutorials/statistical-foundations/**"
   ```

3. Dry-run for the whole repo:
   ```powershell
   python scripts/distribute_vgwort.py `
       --xlsx "F:\Dropbox\Arbeit\Firma\boulingua\VGWort - rh\zaehlmarken_combined.xlsx"
   ```

4. Apply (only after the dry-run output looks right):
   ```powershell
   python scripts/distribute_vgwort.py `
       --xlsx "F:\Dropbox\Arbeit\Firma\boulingua\VGWort - rh\zaehlmarken_combined.xlsx" `
       --apply
   ```

5. Review and commit:
   ```powershell
   git diff
   git add -A
   git commit -m "Embed VG Wort Zählmarken in eligible tutorial pages"
   ```

## What `--apply` does

- Refuses to run if `git status --porcelain` is non-empty.
- Refuses to run if a Dropbox `... CONFLICTED COPY ...` xlsx sits next to
  the original.
- Backs up the xlsx to `<name>.bak.<YYYYMMDD-HHMMSS>` before any write.
- For each eligible page (≥ 1,800 prose chars, no existing marker):
  appends the `::: {.vgwort-pixel}` block, flips that xlsx row to
  `Used=True` with the page URL, and atomically saves the xlsx — one
  marker at a time, in the same transaction as the qmd write.

## CLI

```
--xlsx <path>          Required. Path to zaehlmarken_combined.xlsx.
--apply | --dry-run    Default is --dry-run.
--root <dir>           Default ".". Quarto project root.
--min-chars <n>        Default 1800. VG Wort minimum.
--exclude <glob>       Repeatable. Adds to defaults (docs/**, _freeze/**, ...).
--only <glob>          Repeatable. Restricts to matching paths.
```

## Rolling back

- **qmd changes** (uncommitted): `git checkout -- .`
- **qmd changes** (committed): `git revert <sha>`
- **xlsx**: copy back from `<name>.bak.<timestamp>` next to the original.

If you have to roll back the xlsx, also roll back the qmd writes — the two
must stay in sync.

## Edge cases handled

- `index.qmd` → marker registers `.../index.html`.
- `draft: true` → skipped.
- Files starting with `_` (Quarto include partials) → skipped.
- Existing marker present → reconciled against xlsx (fixes `Used=False`
  rows; warns on URL mismatch; errors on foreign markers not in xlsx).
- Insufficient markers in pool → refuses to partially allocate; aborts
  before any write.

## Exit codes

- `0` — success.
- `1` — completed but with reconciliation anomalies (foreign markers, URL
  mismatches). Review the log.
- `2` — preflight failure (missing xlsx, dirty git tree, Dropbox conflict).
- `3` — allocation halted (insufficient markers).
