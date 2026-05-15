if vim.g.loaded_filemention then return end
vim.g.loaded_filemention = true

-- Auto-register with nvim-cmp if it's loaded. blink.cmp users wire the
-- source through their own config (see README).
local ok, cmp = pcall(require, "cmp")
if ok then
  cmp.register_source("filemention", require("filemention.sources.cmp").new())
end
