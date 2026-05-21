if vim.g.loaded_filemention then return end
vim.g.loaded_filemention = true

-- Auto-register with nvim-cmp if it's loaded. blink.cmp users wire the
-- source through their own config (see README).
local ok, cmp = pcall(require, "cmp")
if ok then
  cmp.register_source("filemention", require("filemention.sources.cmp").new())
end

local group = vim.api.nvim_create_augroup("filemention", { clear = true })
vim.api.nvim_create_autocmd("DirChanged", {
  group = group,
  callback = function() require("filemention.files").invalidate() end,
})

vim.api.nvim_create_user_command("FileMentionRefresh", function()
  require("filemention.files").invalidate()
end, { desc = "Drop filemention's file cache and re-scan on next @ trigger." })
