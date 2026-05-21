---In-plugin frecency store. Score = frequency / (1 + days_since_last_open).
---Mirrors the model opencode (anomalyco) uses for @ completion ranking.
---Persisted as JSONL under stdpath("state")/filemention/frecency.jsonl.
local M = {}

local MAX_ENTRIES = 1000
local MS_PER_DAY = 86400000

local state = {
  data = nil, ---@type table<string, { frequency: integer, last_open: integer }>|nil
  path = nil, ---@type string|nil
}

local function file_path()
  if state.path then return state.path end
  local dir = vim.fn.stdpath("state") .. "/filemention"
  vim.fn.mkdir(dir, "p")
  state.path = dir .. "/frecency.jsonl"
  return state.path
end

local function now_ms() return os.time() * 1000 end

local function ensure_loaded()
  if state.data then return end
  state.data = {}
  local f = io.open(file_path(), "r")
  if not f then return end
  for line in f:lines() do
    local ok, entry = pcall(vim.json.decode, line)
    if ok and type(entry) == "table" and entry.path then
      -- JSONL is append-only; later lines overwrite earlier ones.
      state.data[entry.path] = {
        frequency = entry.frequency or 0,
        last_open = entry.last_open or 0,
      }
    end
  end
  f:close()
end

local function count_entries()
  local n = 0
  for _ in pairs(state.data) do n = n + 1 end
  return n
end

---Rewrite the JSONL file in compact form (one current line per path), keeping
---only the most-recently-used MAX_ENTRIES. Cheap because we hold the whole map.
local function compact()
  local list = {}
  for p, e in pairs(state.data) do
    list[#list + 1] = { path = p, frequency = e.frequency, last_open = e.last_open }
  end
  table.sort(list, function(a, b) return a.last_open > b.last_open end)
  for i = MAX_ENTRIES + 1, #list do
    state.data[list[i].path] = nil
    list[i] = nil
  end
  local f = io.open(file_path(), "w")
  if not f then return end
  for _, e in ipairs(list) do f:write(vim.json.encode(e) .. "\n") end
  f:close()
end

---Read-only frecency score for an absolute path. 0 if never seen.
---@param abs_path string
---@return number
function M.score(abs_path)
  ensure_loaded()
  local e = state.data[abs_path]
  if not e then return 0 end
  local days = (now_ms() - e.last_open) / MS_PER_DAY
  return e.frequency / (1 + days)
end

---Record an access. Updates in-memory state and appends to disk.
---@param abs_path string
function M.update(abs_path)
  ensure_loaded()
  local e = state.data[abs_path] or { frequency = 0, last_open = 0 }
  e.frequency = e.frequency + 1
  e.last_open = now_ms()
  state.data[abs_path] = e

  local f = io.open(file_path(), "a")
  if f then
    f:write(vim.json.encode({ path = abs_path, frequency = e.frequency, last_open = e.last_open }) .. "\n")
    f:close()
  end

  if count_entries() > MAX_ENTRIES then compact() end
end

---Used by tests to start from a clean slate. Not part of the public API.
function M._reset(custom_path)
  state.data = nil
  state.path = custom_path
end

return M
