---Single-pool ranking that mixes files and directories, modelled on
---opencode's @ completion algorithm.
---
---Folders are derived from every parent of every file (with a trailing "/")
---and share the same fuzzy pool as files. Final order combines:
---  - vim.fn.matchfuzzypos score
---  - 2x bonus when the candidate starts with the query (case-insensitive)
---  - 1 + frecency multiplier (recent picks float up)
---  - hidden penalty unless the query is dot-led
---
---For an empty query we skip fuzzy entirely and produce: dirs (alpha),
---then files (frecency -> shallow -> alpha). Hidden last unless preferred.
local frecency = require("filemention.frecency")

local M = {}

---@param p string
---@return boolean
local function is_hidden(p)
  if p:sub(1, 1) == "." then return true end
  return p:find("/%.") ~= nil
end

---@param p string
---@return integer
local function path_depth(p)
  local n = 1
  for _ in p:gmatch("/") do n = n + 1 end
  return n
end

---@param query string
---@return boolean
local function prefer_hidden(query)
  return query:sub(1, 1) == "." or query:find("/%.") ~= nil
end

---Walk every file's ancestor chain and emit a flat list of unique directory
---candidates (each with a trailing "/" so callers can tell them apart from
---files in a mixed list).
---@param files string[]
---@return string[]
function M.derive_all_dirs(files)
  local seen, dirs = {}, {}
  for _, file in ipairs(files) do
    local dir = vim.fs.dirname(file)
    while dir and dir ~= "" and dir ~= "." and dir ~= "/" do
      if seen[dir] then break end
      seen[dir] = true
      dirs[#dirs + 1] = dir .. "/"
      dir = vim.fs.dirname(dir)
    end
  end
  return dirs
end

---Partition into (visible, hidden) preserving relative order, then append
---hidden at the end. If `prefer` is true, no-op.
local function sort_hidden_last(items, prefer)
  if prefer then return items end
  local out, hidden = {}, {}
  for _, it in ipairs(items) do
    if is_hidden(it) then hidden[#hidden + 1] = it else out[#out + 1] = it end
  end
  for _, it in ipairs(hidden) do out[#out + 1] = it end
  return out
end

---Empty-query ordering: dirs first (alpha), then files (frecency desc,
---then shallow depth, then alpha). Hidden last unless preferred.
local function order_empty(root, files, dirs, limit)
  local sorted_dirs = vim.deepcopy(dirs)
  table.sort(sorted_dirs)

  local sorted_files = vim.deepcopy(files)
  table.sort(sorted_files, function(a, b)
    local af = frecency.score(root .. "/" .. a)
    local bf = frecency.score(root .. "/" .. b)
    if af ~= bf then return af > bf end
    local ad, bd = path_depth(a), path_depth(b)
    if ad ~= bd then return ad < bd end
    return a < b
  end)

  local out = {}
  for _, d in ipairs(sorted_dirs) do
    out[#out + 1] = d
    if #out >= limit then return out end
  end
  for _, f in ipairs(sorted_files) do
    out[#out + 1] = f
    if #out >= limit then return out end
  end
  return out
end

---Rank a mixed pool of files and dirs against a fuzzy query.
---@param root string Absolute project root. Used as frecency key prefix.
---@param files string[] Relative file paths.
---@param dirs string[] Relative directory paths, each ending in "/".
---@param query string
---@param limit integer Cap on the returned list.
---@return string[] ranked Candidates in best-first order. Dirs keep trailing "/".
function M.rank(root, files, dirs, query, limit)
  query = query or ""
  local prefer = prefer_hidden(query)

  if query == "" then
    return sort_hidden_last(order_empty(root, files, dirs, limit), prefer)
  end

  local pool = {}
  for _, f in ipairs(files) do pool[#pool + 1] = f end
  for _, d in ipairs(dirs) do pool[#pool + 1] = d end
  if #pool == 0 then return {} end

  -- matchfuzzypos returns [matches, positions, scores] in best-first order.
  local got = vim.fn.matchfuzzypos(pool, query)
  local matches, scores = got[1], got[3]
  if not matches or #matches == 0 then return {} end

  local query_lower = query:lower()
  local qlen = #query
  local ranked = {}
  for i, m in ipairs(matches) do
    local s = scores[i]
    -- Length penalty: matchfuzzy has no implicit length normalization, so two
    -- candidates with the same matched characters score identically regardless
    -- of total length. fuzzysort (opencode) penalizes longer targets, which is
    -- what surfaces shorter folders above their longer descendant files.
    s = s - (#m - qlen)
    -- Small folder bonus to break remaining ties in favour of dirs, since
    -- folder-first feels right for an @-mention drill-in workflow.
    if m:sub(-1) == "/" then s = s + 5 end
    if m:sub(1, qlen):lower() == query_lower then s = s * 2 end
    local f = frecency.score(root .. "/" .. m)
    s = s * (1 + f)
    if not prefer and is_hidden(m) then s = s * 0.25 end
    ranked[#ranked + 1] = { path = m, score = s }
  end
  table.sort(ranked, function(a, b) return a.score > b.score end)

  local out = {}
  for i = 1, math.min(limit, #ranked) do out[i] = ranked[i].path end
  return out
end

return M
