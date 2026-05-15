local config = require("filemention.config")

local M = {}

M.setup = config.setup

---Check whether the source should activate in the given buffer.
---@param bufnr integer
---@return boolean
function M.enabled(bufnr)
  local ft_opt = config.options.filetypes
  if ft_opt == "*" then return true end
  local ft = vim.bo[bufnr].filetype
  return vim.tbl_contains(ft_opt, ft)
end

return M
