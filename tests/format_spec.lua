local format = require("filemention.format")

describe("format.render", function()
  it("bare format prepends the trigger", function()
    local insert, label = format.render("bare", "foo/bar.lua")
    assert.equals("@foo/bar.lua", insert)
    assert.equals("foo/bar.lua", label)
  end)

  it("markdown format produces a real link", function()
    local insert, label = format.render("markdown", "foo/bar.lua")
    assert.equals("[@bar.lua](foo/bar.lua)", insert)
    assert.equals("foo/bar.lua", label)
  end)

  it("function format delegates to the caller", function()
    local fn = function(path, name) return "<" .. name .. ":" .. path .. ">" end
    local insert, label = format.render(fn, "a/b/c.txt")
    assert.equals("<c.txt:a/b/c.txt>", insert)
    assert.equals("a/b/c.txt", label)
  end)
end)
