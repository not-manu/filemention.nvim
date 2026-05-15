---@class filemention.Config
---@field trigger string Character that opens the menu. Default "@".
---@field root "cwd"|"git"|fun():string Where to search from.
---@field respect_gitignore boolean Pass --no-ignore=false to fd/rg.
---@field include_hidden boolean Include dotfiles.
---@field format "bare"|"markdown"|fun(path:string, name:string):string
---@field filetypes string[]|"*" Filetypes the source activates in. Default text-ish only.
---@field max_items integer Cap on returned candidates.
---@field finder "auto"|"fd"|"rg"|"vim" File-listing backend.

---@type filemention.Config
local defaults = {
  trigger = "@",
  root = "git",
  respect_gitignore = true,
  include_hidden = false,
  format = "bare",
  filetypes = { "markdown", "text", "gitcommit", "gitrebase", "markdown.mdx", "mdx", "norg" },
  max_items = 500,
  finder = "auto",
}

local M = { options = vim.deepcopy(defaults) }

---@param opts filemention.Config?
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  return M.options
end

return M
