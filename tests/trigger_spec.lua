local trigger = require("filemention.trigger")

describe("trigger.match", function()
  it("returns nil when no trigger is present", function()
    assert.is_nil(trigger.match("hello world", "@"))
    assert.is_nil(trigger.match("", "@"))
  end)

  it("matches a bare trigger at start of line", function()
    local m = trigger.match("@", "@")
    assert.is_not_nil(m)
    assert.equals("", m.query)
    assert.is_false(m.bracketed)
  end)

  it("captures the query after the trigger", function()
    local m = trigger.match("see @foo/bar", "@")
    assert.is_not_nil(m)
    assert.equals("foo/bar", m.query)
    assert.is_false(m.bracketed)
  end)

  it("detects bracketed mode when preceded by [", function()
    local m = trigger.match("see [@foo", "@")
    assert.is_not_nil(m)
    assert.equals("foo", m.query)
    assert.is_true(m.bracketed)
  end)

  it("stops at whitespace before the cursor", function()
    -- A previous mention shouldn't leak into a fresh one.
    local m = trigger.match("@old new ", "@")
    assert.is_nil(m, "trailing space ends the mention")
  end)

  it("does not match double-trigger", function()
    -- `@@foo` is not an active mention — the second @ resets the run.
    local m = trigger.match("@@foo", "@")
    assert.is_not_nil(m)
    assert.equals("foo", m.query)
  end)

  it("works with a custom trigger character", function()
    local m = trigger.match("hello #file", "#")
    assert.is_not_nil(m)
    assert.equals("file", m.query)
  end)
end)
