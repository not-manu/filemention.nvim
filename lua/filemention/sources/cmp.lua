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
  -- If the @ was preceded by `[`, render as a markdown link regardless of config.
  local fmt = bracketed and "markdown" or config.options.format

  files.list(config.options, query, function(_, paths, ordered)
    local items = {}
    local ok = require("cmp").lsp.CompletionItemKind
    -- When fff returned the list it's already ranked best-first. Pin that
    -- order with sortText and pin filterText to the typed query so cmp
    -- doesn't drop typo-tolerant matches.
    local frozen_filter = ordered and (trig .. query) or nil
    for i, path in ipairs(paths) do
      local insert_text, label = format.render(fmt, path)
      -- In bracketed mode the leading `[` is already in the buffer; strip it
      -- from the inserted text so the result is `[@name](path)`, not `[[@name](path)`.
      if bracketed then insert_text = insert_text:sub(2) end
      items[#items + 1] = {
        label = label,
        insertText = insert_text,
        filterText = frozen_filter or (trig .. path),
        sortText = ordered and string.format("%06d", i) or nil,
        kind = ok.File,
        data = { path = path },
      }
    end
    callback({ items = items, isIncomplete = ordered })
  end)
end

function source:execute(completion_item, callback)
  local path = completion_item.data and completion_item.data.path
  if path then files.track_access(config.options, path) end
  callback(completion_item)
end

return source
