local rank = require("filemention.rank")
local frecency = require("filemention.frecency")

local M = {}

---@param opts filemention.Config
---@return string
local function resolve_root(opts)
  if type(opts.root) == "function" then return opts.root() end
  if opts.root == "git" then
    local out = vim.fs.root(0, { ".git" })
    if out then return out end
  end
  return vim.uv.cwd() or vim.fn.getcwd()
end

local function has(bin) return vim.fn.executable(bin) == 1 end

---@return table|nil fff.file_picker module if its Rust index is live.
local function fff_ready()
  local core_ok, core = pcall(require, "fff.core")
  if not core_ok or not core.is_file_picker_initialized() then return nil end
  local fp_ok, fp = pcall(require, "fff.file_picker")
  if not fp_ok then return nil end
  if not fp.state.initialized then pcall(fp.setup) end
  return fp
end

---@param opts filemention.Config
---@return string backend, string[] argv
local function build_argv(opts)
  local backend = opts.finder
  if backend == "auto" or backend == "fff" then
    if has("fd") then backend = "fd"
    elseif has("rg") then backend = "rg"
    else backend = "vim" end
  end

  if backend == "fd" then
    local argv = { "fd", "--type", "f", "--color", "never" }
    if opts.include_hidden then table.insert(argv, "--hidden") end
    if not opts.respect_gitignore then table.insert(argv, "--no-ignore") end
    return backend, argv
  elseif backend == "rg" then
    local argv = { "rg", "--files", "--color", "never" }
    if opts.include_hidden then table.insert(argv, "--hidden") end
    if not opts.respect_gitignore then table.insert(argv, "--no-ignore") end
    return backend, argv
  end
  return backend, {}
end

---Pure-Lua fallback walker. Caps at `max` files.
---@param root string
---@param max integer
---@return string[]
local function vim_walk(root, max)
  local out = {}
  for name, type in vim.fs.dir(root, { depth = 20 }) do
    if type == "file" then
      out[#out + 1] = name
      if #out >= max then break end
    end
  end
  return out
end

---@class filemention.Item
---@field path string Relative path inside project root.
---@field is_dir boolean

-- Per-root cache. Filled lazily on first list() call, kept alive until an
-- invalidation signal fires (DirChanged or :FileMentionRefresh). The cache
-- holds raw files + derived parent dirs so ranking is a pure transform.
---@type table<string, { files: string[], dirs: string[], ready: boolean, scanning: boolean, pending: function[] }>
local cache = {}

local function cache_for(root)
  local c = cache[root]
  if not c then
    c = { files = {}, dirs = {}, ready = false, scanning = false, pending = {} }
    cache[root] = c
  end
  return c
end

---Wipe one root's cache, or every cache if `root` is nil. Wired up to the
---DirChanged autocmd and to the :FileMentionRefresh user command in plugin/.
---@param root string|nil
function M.invalidate(root)
  if root then cache[root] = nil else cache = {} end
end

local function finalize_scan(root, paths)
  local c = cache_for(root)
  c.files = paths
  c.dirs = rank.derive_all_dirs(paths)
  c.ready = true
  c.scanning = false
  local pending = c.pending
  c.pending = {}
  for _, fn in ipairs(pending) do fn() end
end

local function start_scan(opts, root)
  local c = cache_for(root)
  if c.scanning then return end
  c.scanning = true

  local backend, argv = build_argv(opts)
  if backend == "vim" then
    -- Collect more than max_items so the ranker has headroom; rank truncates.
    return finalize_scan(root, vim_walk(root, opts.max_items * 10))
  end

  vim.system(argv, { cwd = root, text = true }, function(res)
    local paths = {}
    if res.code == 0 and res.stdout then
      for line in res.stdout:gmatch("[^\r\n]+") do paths[#paths + 1] = line end
    end
    vim.schedule(function() finalize_scan(root, paths) end)
  end)
end

local function with_cache(opts, root, cb)
  local c = cache_for(root)
  if c.ready then return cb(c) end
  table.insert(c.pending, function() cb(c) end)
  start_scan(opts, root)
end

---@param opts filemention.Config
---@param query string|nil Text after the trigger.
---@param cb fun(root:string, items:filemention.Item[], ordered:boolean) `ordered` is
---always true now — this module owns the ranking. Sources should freeze filterText
---to the typed query so completion engines don't re-filter and drop entries.
function M.list(opts, query, cb)
  local root = resolve_root(opts)
  local q = query or ""

  if opts.finder == "fff" then
    local fp = fff_ready()
    if fp then
      -- fff already does frecency-aware fuzzy ranking on its Rust index;
      -- we just translate its results and derive matching parent dirs.
      local current = vim.api.nvim_buf_get_name(0)
      if current == "" then current = nil end
      local items = fp.search_files(q, current, opts.max_items, nil, nil) or {}
      local paths = {}
      for _, it in ipairs(items) do paths[#paths + 1] = it.relative_path end
      local dirs = rank.derive_all_dirs(paths)
      local out = {}
      -- Pin matching dirs first (up to a quarter of the popup), then files,
      -- preserving fff's order for files.
      local dir_cap = math.max(1, math.floor(opts.max_items / 4))
      local q_lower = q:lower()
      local emitted = 0
      for _, d in ipairs(dirs) do
        if q == "" or d:lower():find(q_lower, 1, true) then
          out[#out + 1] = { path = d:sub(1, -2), is_dir = true }
          emitted = emitted + 1
          if emitted >= dir_cap then break end
        end
      end
      for _, p in ipairs(paths) do
        out[#out + 1] = { path = p, is_dir = false }
        if #out >= opts.max_items then break end
      end
      return cb(root, out, true)
    end
    -- fff requested but not available: fall through to the cache path.
  end

  with_cache(opts, root, function(c)
    local ranked = rank.rank(root, c.files, c.dirs, q, opts.max_items)
    local items = {}
    for _, p in ipairs(ranked) do
      local is_dir = p:sub(-1) == "/"
      items[#items + 1] = { path = is_dir and p:sub(1, -2) or p, is_dir = is_dir }
    end
    cb(root, items, true)
  end)
end

---Record a file access for ranking purposes. Folders are skipped — the
---frecency model only applies to files. Updates both the in-plugin store
---and fff's tracker when available.
---@param opts filemention.Config
---@param relpath string Relative path returned by files.list.
---@param is_dir boolean?
function M.track_access(opts, relpath, is_dir)
  if is_dir then return end
  local root = resolve_root(opts)
  -- Use root+relpath as the frecency key so lookups during ranking match
  -- exactly (no realpath round-trip per candidate per keystroke).
  frecency.update(root .. "/" .. relpath)

  local fp = fff_ready()
  if not fp then return end
  vim.uv.fs_realpath(root .. "/" .. relpath, function(err, real)
    if err or not real then return end
    pcall(fp.track_access, real)
  end)
end

return M
