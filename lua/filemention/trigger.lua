---Detection of the @-mention prefix in a line.
---Extracted from the cmp/blink sources so it can be unit-tested without a
---completion engine in the loop.
local M = {}

---@class filemention.TriggerMatch
---@field query string Text the user has typed after the trigger.
---@field bracketed boolean True when the trigger was preceded by `[` (markdown link).

---Inspect the text before the cursor for an active mention.
---@param before string Line up to (but not including) the cursor.
---@param trigger string Single-character trigger (e.g. "@").
---@return filemention.TriggerMatch|nil match `nil` when there is no active mention.
function M.match(before, trigger)
  local pat = trigger .. "[^" .. vim.pesc(trigger) .. "%s]*$"
  local at_pos = before:find(pat)
  if not at_pos then return nil end
  return {
    query = before:sub(at_pos + #trigger),
    bracketed = at_pos > 1 and before:sub(at_pos - 1, at_pos - 1) == "[",
  }
end

return M
