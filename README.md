# filemention.nvim

Type `@` in insert mode to fuzzy-pick a project file and insert it as a `@path/to/file` mention. Works with [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) and [blink.cmp](https://github.com/Saghen/blink.cmp).

Use case: writing prompts, notes, or commit messages where you want to reference files inline without leaving insert mode.

## Requirements

- Neovim 0.10+
- [`fd`](https://github.com/sharkdp/fd) or [`rg`](https://github.com/BurntSushi/ripgrep) recommended (falls back to pure-Lua walk)
- A completion engine: `nvim-cmp` or `blink.cmp`

## Install & configure

### lazy.nvim + nvim-cmp

```lua
{
  "not-manu/filemention.nvim",
  dependencies = { "hrsh7th/nvim-cmp" },
  opts = {},  -- see Configuration
  -- the source registers itself; just add it to your cmp sources:
  -- sources = cmp.config.sources({ { name = "filemention" }, { name = "buffer" } })
}
```

### lazy.nvim + blink.cmp

```lua
{
  "not-manu/filemention.nvim",
  opts = {},
},
{
  "saghen/blink.cmp",
  opts = {
    sources = {
      default = { "filemention", "lsp", "buffer", "path" },
      providers = {
        filemention = {
          name = "filemention",
          module = "filemention.sources.blink",
        },
      },
    },
  },
}
```

## Configuration

```lua
require("filemention").setup({
  trigger = "@",                      -- character that opens the menu
  root = "git",                       -- "git" | "cwd" | function() return path end
  respect_gitignore = true,
  include_hidden = false,
  format = "bare",                    -- "bare" => @path/to/file
                                      -- "markdown" => [@file](path/to/file)
                                      -- function(path, name) return "..." end
  filetypes = { "markdown", "text", "gitcommit" },  -- or "*" for all
  max_items = 500,
  finder = "auto",                    -- "auto" | "fd" | "rg" | "vim"
})
```

## License

MIT
