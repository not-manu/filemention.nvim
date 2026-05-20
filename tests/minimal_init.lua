-- Bootstraps a minimal runtimepath for headless test runs.
-- Expects plenary.nvim to live at .tests/site/pack/deps/start/plenary.nvim
-- (the CI workflow clones it there; locally you can do the same).
local cwd = vim.fn.getcwd()
vim.opt.runtimepath:prepend(cwd)
vim.opt.runtimepath:prepend(cwd .. "/.tests/site/pack/deps/start/plenary.nvim")
vim.opt.packpath = { cwd .. "/.tests/site" }

vim.cmd("runtime! plugin/plenary.vim")
