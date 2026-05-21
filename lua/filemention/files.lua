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
---NOTE: `fff.file_picker.is_initialized()` only flips true once the user opens
---fff's picker UI — it's not the right gate for "is the index ready". The Rust
---index is brought up by `fff.core.ensure_initialized()` on UIEnter, which sets
---`fff.core.is_file_picker_initialized()`. That is the gate we want.
local function fff_ready()
  local core_ok, core = pcall(require, "fff.core")
  if not core_ok or not core.is_file_picker_initialized() then return nil end
  local fp_ok, fp = pcall(require, "fff.file_picker")
  if not fp_ok then return nil end
  -- `fp.search_files` early-returns {} unless `fp.state.initialized` is true,
  -- which is normally only flipped by fff's own picker UI. Idempotently flip
  -- it ourselves so we can use the Rust index without opening the UI.
  if not fp.state.initialized then pcall(fp.setup) end
  return fp
end

---@param opts filemention.Config
---@return string backend, string[] argv
local function build_argv(opts)
  local backend = opts.finder
  -- "fff" handled upstream in M.list; if we reach here with "fff" it means
  -- fff wasn't available, so auto-detect like a normal fallback.
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

---Walk filesystem in pure Lua as a fallback.
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

---Subsequence match: returns true if every char of `needle` appears in
---`haystack` in order. Both arguments must already be lowercased by the caller.
local function subseq_lower(haystack, needle)
  if needle == "" then return true end
  local hi, ni = 1, 1
  local hlen, nlen = #haystack, #needle
  while hi <= hlen and ni <= nlen do
    if haystack:byte(hi) == needle:byte(ni) then ni = ni + 1 end
    hi = hi + 1
  end
  return ni > nlen
end

---Derive parent directories from a ranked file list. Folders are emitted in
---encounter order so the upstream ranking (fff frecency, fd/rg traversal)
---carries over. When a query is present, only ancestors whose path
---subsequence-matches the query are kept; with no query we emit every unique
---parent dir (capped) so users can browse folders too.
---@param paths string[]
---@param query string
---@param max integer
---@return string[]
local function derive_dirs(paths, query, max)
  local q = (query or ""):lower()
  local seen, dirs = {}, {}
  for _, p in ipairs(paths) do
    local dir = vim.fs.dirname(p)
    while dir and dir ~= "" and dir ~= "." and dir ~= "/" do
      if seen[dir] then break end
      seen[dir] = true
      if q == "" or subseq_lower(dir:lower(), q) then
        dirs[#dirs + 1] = dir
        if #dirs >= max then return dirs end
      end
      dir = vim.fs.dirname(dir)
    end
  end
  return dirs
end

---@class filemention.Item
---@field path string Relative path inside project root.
---@field is_dir boolean

---@param paths string[]
---@param query string|nil
---@param max integer Cap on total items (dirs + files).
---@return filemention.Item[]
local function with_dirs(paths, query, max)
  local items = {}
  -- Cap dirs at roughly a quarter of the popup so they prioritize without
  -- crowding out actual file matches.
  local dir_cap = math.max(1, math.floor(max / 4))
  for _, d in ipairs(derive_dirs(paths, query or "", dir_cap)) do
    items[#items + 1] = { path = d, is_dir = true }
    if #items >= max then return items end
  end
  for _, p in ipairs(paths) do
    items[#items + 1] = { path = p, is_dir = false }
    if #items >= max then break end
  end
  return items
end

---@param opts filemention.Config
---@param query string|nil In-progress query (text after the trigger). Only the
---fff backend uses this; subprocess backends ignore it and rely on the completion
---engine to filter client-side.
---@param cb fun(root:string, items:filemention.Item[], ordered:boolean) `ordered` is
---true when the backend already returned results in best-first order (fff); false
---otherwise. Folders (is_dir=true) are always emitted ahead of files.
function M.list(opts, query, cb)
  local root = resolve_root(opts)

  if opts.finder == "fff" then
    local fp = fff_ready()
    if fp then
      local current = vim.api.nvim_buf_get_name(0)
      if current == "" then current = nil end
      local items = fp.search_files(query or "", current, opts.max_items, nil, nil) or {}
      local paths = {}
      for _, it in ipairs(items) do
        paths[#paths + 1] = it.relative_path
      end
      return cb(root, with_dirs(paths, query, opts.max_items), true)
    end
    -- fff requested but not available: fall through to auto-detected backend.
  end

  local backend, argv = build_argv(opts)

  if backend == "vim" then
    return cb(root, with_dirs(vim_walk(root, opts.max_items), query, opts.max_items), false)
  end

  local stdout = {}
  vim.system(argv, { cwd = root, text = true }, function(res)
    if res.code ~= 0 or not res.stdout then
      return vim.schedule(function() cb(root, {}, false) end)
    end
    for line in res.stdout:gmatch("[^\r\n]+") do
      stdout[#stdout + 1] = line
      if #stdout >= opts.max_items then break end
    end
    vim.schedule(function() cb(root, with_dirs(stdout, query, opts.max_items), false) end)
  end)
end

---Record a file access with fff's frecency tracker, if available. No-op otherwise.
---fff stores frecency keyed by absolute realpath, so the relative path is resolved
---against the project root before reporting.
---@param opts filemention.Config
---@param relpath string Relative path returned by files.list.
---@param is_dir boolean? Folders are skipped — fff's frecency index keys on files.
function M.track_access(opts, relpath, is_dir)
  if is_dir then return end
  local fp = fff_ready()
  if not fp then return end
  local root = resolve_root(opts)
  local joined = root .. "/" .. relpath
  vim.uv.fs_realpath(joined, function(err, real)
    if err or not real then return end
    pcall(fp.track_access, real)
  end)
end

return M
