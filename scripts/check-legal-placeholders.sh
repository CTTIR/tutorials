#!/bin/sh
# check-legal-placeholders.sh
#
# Fail the build if rendered output still contains placeholder
# tokens or TODO/FIXME markers in legal pages.
#
# Default scan target: ./docs (Quarto output-dir for this repo).
# Override with: BUILD_DIR=_site bash scripts/check-legal-placeholders.sh

set -eu

BUILD_DIR="${BUILD_DIR:-docs}"

if [ ! -d "$BUILD_DIR" ]; then
  echo "[check-legal-placeholders] build dir '$BUILD_DIR' not found — run the site build first" >&2
  exit 2
fi

fail=0

for needle in '{{CONTACT_EMAIL_HELLER}}' '{{CONTACT_EMAIL_LEBOULANGER}}' '{{SITE_DOMAIN}}'; do
  hits=$(grep -rl -F "$needle" "$BUILD_DIR" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "[check-legal-placeholders] FAIL: placeholder $needle found in:" >&2
    echo "$hits" >&2
    fail=1
  fi
done

# TODO/FIXME inside legal pages only
for marker in 'TODO' 'FIXME'; do
  hits=$(find "$BUILD_DIR" -type d \( -name 'legal' -o -name 'rechtliches' \) -prune -print 2>/dev/null \
    | xargs -r -I{} grep -rl -F "$marker" {} 2>/dev/null || true)
  legalfiles=$(find "$BUILD_DIR" -type f \( -name 'impressum*' -o -name 'datenschutz*' -o -name 'haftungsausschluss*' -o -name 'privacy*' -o -name 'imprint*' -o -name 'disclaimer*' \) 2>/dev/null || true)
  if [ -n "$legalfiles" ]; then
    matches=$(echo "$legalfiles" | xargs -r grep -l -F "$marker" 2>/dev/null || true)
    if [ -n "$matches" ]; then
      echo "[check-legal-placeholders] FAIL: $marker found in legal pages:" >&2
      echo "$matches" >&2
      fail=1
    fi
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "[check-legal-placeholders] one or more checks failed; refusing to ship" >&2
  exit 1
fi

echo "[check-legal-placeholders] ok — no unfilled placeholders in $BUILD_DIR"
