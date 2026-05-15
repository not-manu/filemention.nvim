<picture>
  <source srcset="./assets/logo-dark.svg" media="(prefers-color-scheme: dark)"/>
  <source srcset="./assets/logo-light.svg" media="(prefers-color-scheme: light)"/>
  <img src="./assets/logo-light.svg" style="width: 48px; height: 48px;" width="48" height="48"/>
</picture>
<br/>
<br/>
<b>filemention.nvim</b>
<br/>
<br/>
type <code>@</code> in insert mode.
<br/>
fuzzy-pick a file.
<br/>
<br/>
get a <code>@path/to/file</code> mention — native to nvim.

<br/>
<br/>

<img src="./assets/demo.gif" alt="filemention.nvim demo" width="720"/>

<br/>
<br/>
<br/>

### install

with [lazy.nvim](https://github.com/folke/lazy.nvim) and [nvim-cmp](https://github.com/hrsh7th/nvim-cmp):

```lua
{ "not-manu/filemention.nvim", event = "InsertEnter", opts = {} }
```

then add `{ name = "filemention" }` to your cmp sources. that's it.

[blink.cmp](https://github.com/Saghen/blink.cmp) folks — there's a snippet in [`doc/filemention.txt`](./doc/filemention.txt). you know the drill.

### config

defaults are sensible. but if you must:

```lua
require("filemention").setup({
  trigger = "@",                  -- the magic key
  root = "git",                   -- "git" | "cwd" | function() return path end
  respect_gitignore = true,       -- don't surface your node_modules sins
  include_hidden = false,
  format = "bare",                -- "bare" | "markdown" | function(path, name)
  filetypes = { "markdown", "text", "gitcommit" },  -- or "*" if you live dangerously
  max_items = 500,
  finder = "auto",                -- "auto" | "fd" | "rg" | "vim"
})
```

### the `[@` trick

type `[@` instead of `@` and you get a real markdown link:

```
[@README.md](README.md)
```

handy when you're writing actual prose and the bare `@path` looks ugly.

### under the hood

- file discovery via `fd` → `rg` → pure-lua `vim.fs.dir` (whichever it finds first)
- git root by default, falls back to cwd
- only activates in text-ish filetypes so it doesn't pop up while you're writing real code
- no dependencies beyond your completion engine

<br/>
<br/>
<br/>

<div align="right">
<i>...yet another one of manu's creations</i> &nbsp;&bull;&nbsp; <a href="./LICENSE">MIT</a>
</div>
