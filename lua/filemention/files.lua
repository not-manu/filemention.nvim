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
---@param cb fun(root:string, files:string[])
function M.list(opts, cb)
  local root = resolve_root(opts)
  local backend, argv = build_argv(opts)

  if backend == "vim" then
    return cb(root, vim_walk(root, opts.max_items))
  end

  local stdout = {}
  vim.system(argv, { cwd = root, text = true }, function(res)
    if res.code ~= 0 or not res.stdout then
      return vim.schedule(function() cb(root, {}) end)
    end
    for line in res.stdout:gmatch("[^\r\n]+") do
      stdout[#stdout + 1] = line
      if #stdout >= opts.max_items then break end
    end
    vim.schedule(function() cb(root, stdout) end)
  end)
end

return M
