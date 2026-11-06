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

## Counting pixels

No VG Wort counting pixels are included. Publication checks reject counting endpoints and pixel metadata.

## CI-Guard

```bash
bash scripts/check-legal-placeholders.sh
```

Scannt das gerenderte `docs/`-Verzeichnis auf
`{{CONTACT_EMAIL_HELLER}}`, `{{CONTACT_EMAIL_LEBOULANGER}}`,
`{{SITE_DOMAIN}}` sowie auf `TODO`/`FIXME` in den
Rechtliches-Seiten und schlägt bei Treffern fehl.
