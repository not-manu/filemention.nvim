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

---@return table|nil fff.file_picker module if installed and initialized
local function fff_ready()
  local ok, fp = pcall(require, "fff.file_picker")
  if not ok then return nil end
  if not fp.is_initialized or not fp.is_initialized() then return nil end
  return fp
end

---@param opts filemention.Config
---@return string backend, string[] argv
local function build_argv(opts)
  local backend = opts.finder
  if backend == "auto" then
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

---@param opts filemention.Config
---@param query string|nil In-progress query (text after the trigger). Only the
---fff backend uses this; subprocess backends ignore it and rely on the completion
---engine to filter client-side.
---@param cb fun(root:string, files:string[], ordered:boolean) `ordered` is true when
---the backend already returned results in best-first order (fff); false otherwise.
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
      return cb(root, paths, true)
    end
    -- fff requested but not available: fall through to auto-detected backend.
  end

  local backend, argv = build_argv(opts)

  if backend == "vim" then
    return cb(root, vim_walk(root, opts.max_items), false)
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
    vim.schedule(function() cb(root, stdout, false) end)
  end)
end

---Record a file access with fff's frecency tracker, if available. No-op otherwise.
---fff stores frecency keyed by absolute realpath, so the relative path is resolved
---against the project root before reporting.
---@param opts filemention.Config
---@param relpath string Relative path returned by files.list.
function M.track_access(opts, relpath)
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
