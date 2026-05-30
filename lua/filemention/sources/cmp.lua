---nvim-cmp source for @file mentions.
local config = require("filemention.config")
local files = require("filemention.files")
local format = require("filemention.format")
local trigger = require("filemention.trigger")
local filemention = require("filemention")

local source = {}

function source.new() return setmetatable({}, { __index = source }) end

function source:is_available()
  return filemention.enabled(vim.api.nvim_get_current_buf())
end

function source.get_trigger_characters() return { config.options.trigger } end

---Keyword pattern: capture everything after `@` until whitespace.
function source.get_keyword_pattern()
  local t = vim.pesc(config.options.trigger)
  return t .. [[\S*]]
end

function source:complete(params, callback)
  local trig = config.options.trigger
  local ctx = params.context
  local m = trigger.match(ctx.cursor_before_line, ctx.cursor_after_line, trig)
  if not m then return callback() end

  local query, bracketed, trailing_bracket = m.query, m.bracketed, m.trailing_bracket
  -- If the @ was preceded by `[`, render as a markdown link regardless of config.
  local fmt = bracketed and "markdown" or config.options.format

  files.list(config.options, query, function(_, entries, ordered)
    local items = {}
    local Kind = require("cmp").lsp.CompletionItemKind
    -- When fff returned the list it's already ranked best-first. Pin that
    -- order with sortText and pin filterText to the typed query so cmp
    -- doesn't drop typo-tolerant matches.
    local frozen_filter = ordered and (trig .. query) or nil
    for i, entry in ipairs(entries) do
      local insert_text, label = format.render(fmt, entry.path, entry.is_dir)
      -- In bracketed mode the leading `[` is already in the buffer; strip it
      -- from the inserted text so the result is `[@name](path)`, not `[[@name](path)`.
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
    callback({ items = items, isIncomplete = ordered })
  end)
end

function source:execute(completion_item, callback)
  local data = completion_item.data
  if data and data.path then files.track_access(config.options, data.path, data.is_dir) end
  -- Auto-pair leftovers: if `[` had expanded to `[]` before completion fired,
  -- the trailing `]` is now sitting right after the inserted `[@…](…) `. Eat it.
  if data and data.trailing_bracket then
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    if line:sub(col + 1, col + 1) == "]" then
      vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col + 1, { "" })
    end
  end
  callback(completion_item)
end

return source
