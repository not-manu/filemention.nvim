---nvim-cmp source for @file mentions.
local config = require("filemention.config")
local files = require("filemention.files")
local format = require("filemention.format")
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
  local trigger = config.options.trigger
  local before = params.context.cursor_before_line
  if not before:find(trigger, 1, true) then return callback() end

  files.list(config.options, function(_, paths)
    local items = {}
    local ok = require("cmp").lsp.CompletionItemKind
    for _, path in ipairs(paths) do
      local insert_text, label = format.render(config.options.format, path)
      items[#items + 1] = {
        label = label,
        insertText = insert_text,
        filterText = trigger .. path,
        kind = ok.File,
      }
    end
    callback({ items = items, isIncomplete = false })
  end)
end

return source
