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
    local Kind = require("cmp").lsp.CompletionItemKind
    -- See sources/blink.lua for the rationale: we own the ranking, so freeze
    -- both the filter and the order so cmp doesn't re-shuffle.
    local frozen_filter = ordered and (trig .. query) or nil

    -- Two cmp default comparators fight our ordering:
    --   compare.kind   — orders by LSP enum (File=17 < Folder=19), putting
    --                    every file above every folder.
    --   compare.length — orders by label byte length, putting every short
    --                    label (i.e. every folder) above every long one.
    -- compare.sort_text is commented out in cmp's default config, so without
    -- neutralising both of the above our sortText is never consulted.
    --
    -- Fix: assign the same kind to every item (compare.kind ties), and pad
    -- every label to the same byte length (compare.length ties). compare.order
    -- then runs on insertion order, which is exactly what the ranker chose.
    local prepared = {}
    local max_len = 0
    for _, entry in ipairs(entries) do
      local insert_text, label = format.render(fmt, entry.path, entry.is_dir)
      if bracketed then insert_text = insert_text:sub(2) end
      prepared[#prepared + 1] = { insert_text = insert_text, label = label, entry = entry }
      if #label > max_len then max_len = #label end
    end

    local items = {}
    for i, p in ipairs(prepared) do
      local padded = p.label .. string.rep(" ", max_len - #p.label)
      items[i] = {
        label = padded,
        insertText = p.insert_text,
        filterText = frozen_filter or (trig .. p.entry.path),
        sortText = string.format("%06d", i),
        kind = Kind.File,
        data = { path = p.entry.path, is_dir = p.entry.is_dir },
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
