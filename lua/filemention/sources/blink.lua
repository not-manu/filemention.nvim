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
  local m = trigger.match(ctx.line:sub(1, ctx.cursor[2]), trig)
  if not m then
    return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
  end

  local query, bracketed = m.query, m.bracketed
  local fmt = bracketed and "markdown" or config.options.format

  files.list(config.options, query, function(_, paths, ordered)
    local items = {}
    -- When fff returned the list it's already ranked best-first. We pin that
    -- order with sortText and pin filterText to whatever the user typed so
    -- blink doesn't drop typo-tolerant matches.
    local frozen_filter = ordered and (trig .. query) or nil
    for i, path in ipairs(paths) do
      local insert_text, label = format.render(fmt, path)
      if bracketed then insert_text = insert_text:sub(2) end
      items[#items + 1] = {
        label = label,
        insertText = insert_text,
        filterText = frozen_filter or (trig .. path),
        sortText = ordered and string.format("%06d", i) or nil,
        kind = vim.lsp.protocol.CompletionItemKind.File,
        data = { path = path },
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

function source:execute(_, item)
  local path = item.data and item.data.path
  if path then files.track_access(config.options, path) end
end

return source
