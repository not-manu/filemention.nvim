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
  local m = trigger.match(params.context.cursor_before_line, trig)
  if not m then return callback() end

  local query, bracketed = m.query, m.bracketed
  local fmt = bracketed and "markdown" or config.options.format

  files.list(config.options, query, function(_, entries, ordered)
    local items = {}
    local Kind = require("cmp").lsp.CompletionItemKind
    -- See sources/blink.lua for the rationale: we own the ranking, so freeze
    -- both the filter and the order so cmp doesn't re-shuffle.
    local frozen_filter = ordered and (trig .. query) or nil
    for i, entry in ipairs(entries) do
      local insert_text, label = format.render(fmt, entry.path, entry.is_dir)
      if bracketed then insert_text = insert_text:sub(2) end
      items[#items + 1] = {
        label = label,
        insertText = insert_text,
        filterText = frozen_filter or (trig .. entry.path),
        sortText = string.format("%06d", i),
        kind = entry.is_dir and Kind.Folder or Kind.File,
        data = { path = entry.path, is_dir = entry.is_dir },
      }
    end
    callback({ items = items, isIncomplete = ordered })
  end)
end

function source:execute(completion_item, callback)
  local data = completion_item.data
  if data and data.path then files.track_access(config.options, data.path, data.is_dir) end
  callback(completion_item)
end

return source
