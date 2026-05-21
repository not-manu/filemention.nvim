local M = {}

---@param fmt "bare"|"markdown"|fun(path:string, name:string):string
---@param path string Relative path inside project root.
---@param is_dir boolean? When true, the path is rendered with a trailing slash
---so folder mentions are visually distinct from file mentions in the buffer.
---@return string insert_text, string label
function M.render(fmt, path, is_dir)
  local display = is_dir and (path .. "/") or path
  local name = vim.fs.basename(path)
  if is_dir then name = name .. "/" end
  if type(fmt) == "function" then
    return fmt(display, name), display
  end
  if fmt == "markdown" then
    return ("[@%s](%s) "):format(name, display), display
  end
  return "@" .. display .. " ", display
end

return M
