---blink.cmp source for @file mentions.
local config = require("filemention.config")
local files = require("filemention.files")
local format = require("filemention.format")
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
  local trigger = config.options.trigger
  local before = ctx.line:sub(1, ctx.cursor[2])
  local at_pos = before:find(trigger .. "[^" .. vim.pesc(trigger) .. "%s]*$")
  if not at_pos then
    return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
  end

  local bracketed = at_pos > 1 and before:sub(at_pos - 1, at_pos - 1) == "["
  local fmt = bracketed and "markdown" or config.options.format

  files.list(config.options, function(_, paths)
    local items = {}
    for _, path in ipairs(paths) do
      local insert_text, label = format.render(fmt, path)
      if bracketed then insert_text = insert_text:sub(2) end
      items[#items + 1] = {
        label = label,
        insertText = insert_text,
        filterText = trigger .. path,
        kind = vim.lsp.protocol.CompletionItemKind.File,
      }
    end
    vim.schedule(function()
      callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
    end)
  end)
end

return source
