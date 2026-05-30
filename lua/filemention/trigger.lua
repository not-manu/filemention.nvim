---Detection of the @-mention prefix in a line.
---Extracted from the cmp/blink sources so it can be unit-tested without a
---completion engine in the loop.
local M = {}

---@class filemention.TriggerMatch
---@field query string Text the user has typed after the trigger.
---@field bracketed boolean True when the trigger was preceded by `[` (markdown link).
---@field trailing_bracket boolean True when bracketed AND the very next char after
---the cursor is `]`. This is the auto-pair `[]` case: sources should consume that
---stray `]` when inserting the completion so the buffer doesn't end up with
---`[@name](path) ]`.

---Inspect the text around the cursor for an active mention.
---@param before string Line up to (but not including) the cursor.
---@param after_or_trigger string|nil Either the text after the cursor (new
---two-arg form) or the trigger character (legacy single-line form, kept so
---existing tests/callers don't break).
---@param trigger string|nil Single-character trigger (e.g. "@") when `after_or_trigger`
---is the after-cursor text. Omit when calling with the legacy signature.
---@return filemention.TriggerMatch|nil match `nil` when there is no active mention.
function M.match(before, after_or_trigger, trigger)
  local after
  if trigger == nil then
    -- Legacy `match(before, trigger)` — no after-cursor text available.
    trigger, after = after_or_trigger, ""
  else
    after = after_or_trigger or ""
  end

  local pat = trigger .. "[^" .. vim.pesc(trigger) .. "%s]*$"
  local at_pos = before:find(pat)
  if not at_pos then return nil end

  local bracketed = at_pos > 1 and before:sub(at_pos - 1, at_pos - 1) == "["
  return {
    query = before:sub(at_pos + #trigger),
    bracketed = bracketed,
    trailing_bracket = bracketed and after:sub(1, 1) == "]",
  }
end

return M
