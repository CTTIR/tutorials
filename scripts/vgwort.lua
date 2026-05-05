-- VG Wort Zählpixel (Standard counting) Pandoc/Quarto filter.
--
-- Reads `vgwort_pixel` (or `vgwort-pixel`) from a document's YAML
-- front matter and appends a 1x1 invisible img tag pointing at
-- the VG Wort counting URL just before the body ends.
--
-- The token must be the full path component returned by VG Wort
-- T.O.M., e.g. `vg08.met.vgwort.de/na/<32-hex-token>`. We accept
-- either the full URL or just the token+server combo. If only a
-- bare token is given (32 hex chars), we assume the default
-- `vg08.met.vgwort.de/na/` prefix.
--
-- Usage in a .qmd file:
--   ---
--   title: "My counted article"
--   vgwort_pixel: "vg08.met.vgwort.de/na/0123456789abcdef0123456789abcdef"
--   ---
--
-- The pixel is only emitted if the metadata key is present and
-- non-empty. Pages without the key emit nothing.

local function build_url(token)
  if token:match("^https?://") then return token end
  if token:match("^vg%w+%.met%.vgwort%.de/") then
    return "https://" .. token
  end
  -- Bare token: assume default counting server
  return "https://vg08.met.vgwort.de/na/" .. token
end

function Pandoc(doc)
  local key = doc.meta["vgwort_pixel"] or doc.meta["vgwort-pixel"]
  if not key then return nil end
  local token = pandoc.utils.stringify(key)
  if token == "" then return nil end
  local url = build_url(token)
  local img = string.format(
    '<img src="%s" width="1" height="1" alt="" loading="lazy" referrerpolicy="no-referrer" style="position:absolute;left:-9999px;" />',
    url
  )
  table.insert(doc.blocks, pandoc.RawBlock("html", img))
  return doc
end
