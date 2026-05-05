# Legal pages — Pflege- und Build-Hinweise

Dieses Repository enthält eine konsolidierte Rechtliches-Seite:

- `impressum.qmd` — Impressum (§ 5 DDG, § 18 Abs. 2 MStV),
  Datenschutzerklärung und Haftungsausschluss in einem Dokument.

Im Header oben rechts als **Impressum**, im Footer ebenfalls als
einzelner Link inkl. Kontakt. Aliase
(`/datenschutz.html`, `/haftungsausschluss.html`, `/privacy/`,
`/disclaimer/`, …) verweisen auf die konsolidierte Seite.

## Plausible Analytics

Selbst gehostet auf `analytics.hellebo.de` (Server in
Deutschland), eingebunden via `_quarto.yml` →
`format.html.include-in-header`. Cookielos, IP wird nicht
gespeichert.

## VG Wort Standard-Zählpixel

Pandoc-Lua-Filter `scripts/vgwort.lua`, in `_quarto.yml` unter
`filters:` aktiviert.

### Workflow pro zählpflichtigem Tutorial

1. Token aus [VG Wort T.O.M.](https://tom.vgwort.de/) ziehen.
2. Mindestens **1.500 Zeichen** Text (METIS-Standardverfahren).
3. In der YAML-Frontmatter der Tutorial-Seite:
   ```yaml
   ---
   title: "Mein Tutorial"
   vgwort_pixel: "vg08.met.vgwort.de/na/<32-hex-token>"
   ---
   ```
4. Übersichten, Listings, Impressum, 404 und Werke
   unter 1.500 Zeichen bleiben pixelfrei.

`vgwort_audit.csv` im Repo-Root kann als Verzeichnis aller
zugewiesenen Tokens gepflegt werden (Tutorial-Slug, Datum,
Token).

## CI-Guard

```bash
bash scripts/check-legal-placeholders.sh
```

Scannt das gerenderte `docs/`-Verzeichnis auf
`{{CONTACT_EMAIL_HELLER}}`, `{{CONTACT_EMAIL_LEBOULANGER}}`,
`{{SITE_DOMAIN}}` sowie auf `TODO`/`FIXME` in den
Rechtliches-Seiten und schlägt bei Treffern fehl.
