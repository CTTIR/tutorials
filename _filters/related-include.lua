-- Inject the static "Related tutorials" partial into each tutorial page.
--
-- Pre-render emits _includes/related/<topic>__<slug>.html via
-- scripts/build_related.py. This filter looks up the partial that
-- matches the current document and appends it to the rendered body.
-- Replaces the previous client-side js/related.js (zero JS request).
--
-- Activates only on tutorial detail pages — not the topic index pages,
-- not non-tutorial pages (about, impressum, decision-tree, shiny, etc.).

local function read_file(path)
  local fh = io.open(path, "rb")
  if not fh then return nil end
  local s = fh:read("*a")
  fh:close()
  return s
end

local function detect_partial(input_file)
  if not input_file then return nil end
  -- Normalise separators so the same pattern works on Windows + Linux.
  local p = input_file:gsub("\\", "/")
  -- Match tutorials/<topic>/<slug>.qmd anywhere in the path.
  local topic, slug = p:match("tutorials/([^/]+)/([^/]+)%.qmd$")
  if not topic or not slug or slug == "index" then return nil end
  return topic .. "__" .. slug
end

function Pandoc(doc)
  -- quarto.doc.input_file is the absolute path to the source .qmd.
  local src = quarto and quarto.doc and quarto.doc.input_file
  local key = detect_partial(src)
  if not key then return nil end

  -- Resolve _includes/related/<key>.html relative to the project root.
  -- The filter file lives at <project>/_filters/, so two levels up gives
  -- the project root. PANDOC_STATE.input_files[1] is unreliable here.
  local self_path = debug.getinfo(1, "S").source:sub(2):gsub("\\", "/")
  local project_root = self_path:gsub("/_filters/[^/]+$", "")
  local partial_path = project_root .. "/_includes/related/" .. key .. ".html"

  local html = read_file(partial_path)
  if not html or html == "" then return nil end

  table.insert(doc.blocks, pandoc.RawBlock("html", html))
  return doc
end
