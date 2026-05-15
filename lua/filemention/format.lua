local M = {}

---@param fmt "bare"|"markdown"|fun(path:string, name:string):string
---@param path string Relative path inside project root.
---@return string insert_text, string label
function M.render(fmt, path)
  local name = vim.fs.basename(path)
  if type(fmt) == "function" then
    return fmt(path, name), path
  end
  if fmt == "markdown" then
    return ("[@%s](%s)"):format(name, path), path
  end
  return "@" .. path, path
end

return M
