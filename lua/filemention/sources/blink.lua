---blink.cmp source for @file mentions.
local config = require("filemention.config")
local files = require("filemention.files")
local format = require("filemention.format")
local trigger = require("filemention.trigger")
local filemention = require("filemention")

--- @class filemention.BlinkSource : blink.cmp.Source
local source = {}

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  if opts and next(opts) then config.setup(opts) end
  return self
end

function source:enabled() return filemention.enabled(vim.api.nvim_get_current_buf()) end

function source:get_trigger_characters() return { config.options.trigger } end

function source:get_completions(ctx, callback)
  local trig = config.options.trigger
  local col = ctx.cursor[2]
  local before = ctx.line:sub(1, col)
  local after = ctx.line:sub(col + 1)
  local m = trigger.match(before, after, trig)
  if not m then
    return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
  end

  local query, bracketed, trailing_bracket = m.query, m.bracketed, m.trailing_bracket
  local fmt = bracketed and "markdown" or config.options.format

  files.list(config.options, query, function(_, entries, ordered)
    local items = {}
    -- When fff returned the list it's already ranked best-first. We pin that
    -- order with sortText and pin filterText to whatever the user typed so
    -- blink doesn't drop typo-tolerant matches.
    local frozen_filter = ordered and (trig .. query) or nil
    local Kind = vim.lsp.protocol.CompletionItemKind
    for i, entry in ipairs(entries) do
      local insert_text, label = format.render(fmt, entry.path, entry.is_dir)
      if bracketed then insert_text = insert_text:sub(2) end
      -- Folders take a leading "0" bucket so they sort above files ("1") in
      -- the popup regardless of whether the backend produced ordered results.
      local bucket = entry.is_dir and "0" or "1"
      items[#items + 1] = {
        label = label,
        insertText = insert_text,
        filterText = frozen_filter or (trig .. entry.path),
        sortText = bucket .. string.format("%06d", i),
        kind = entry.is_dir and Kind.Folder or Kind.File,
        data = {
          path = entry.path,
          is_dir = entry.is_dir,
          trailing_bracket = trailing_bracket,
        },
      }
    end
    vim.schedule(function()
      callback({
        is_incomplete_forward = ordered,
        is_incomplete_backward = ordered,
        items = items,
      })
    end)
  end)
end

function source:execute(_, item, callback, default_implementation)
  default_implementation()
  local data = item.data
  if data and data.path then files.track_access(config.options, data.path, data.is_dir) end
  -- Auto-pair leftovers: if `[` had expanded to `[]` before completion fired,
  -- the trailing `]` is now sitting right after the inserted `[@…](…) `. Eat it.
  if data and data.trailing_bracket then
    local row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    if line:sub(cur_col + 1, cur_col + 1) == "]" then
      vim.api.nvim_buf_set_text(0, row - 1, cur_col, row - 1, cur_col + 1, { "" })
    end
  end
  callback()
end

return source
