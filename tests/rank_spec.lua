local rank = require("filemention.rank")
local frecency = require("filemention.frecency")

local function isolate_frecency()
  frecency._reset(vim.fn.tempname())
end

describe("rank.derive_all_dirs", function()
  it("emits unique parent directories with trailing slash", function()
    local dirs = rank.derive_all_dirs({ "a.txt", "src/b.lua", "src/inner/c.lua" })
    table.sort(dirs)
    assert.are.same({ "src/", "src/inner/" }, dirs)
  end)

  it("returns an empty list when nothing has a parent", function()
    assert.are.same({}, rank.derive_all_dirs({ "a.txt", "b.lua" }))
  end)
end)

describe("rank.rank empty query", function()
  before_each(isolate_frecency)

  it("returns dirs first (alpha), then files (depth-asc, alpha)", function()
    local files = { "src/inner/c.lua", "src/b.lua", "a.txt" }
    local dirs = { "src/", "src/inner/" }
    local got = rank.rank("/proj", files, dirs, "", 100)
    assert.are.same({
      "src/",
      "src/inner/",
      "a.txt",
      "src/b.lua",
      "src/inner/c.lua",
    }, got)
  end)

  it("sinks hidden files to the bottom unless the query is dot-led", function()
    local got = rank.rank("/proj", { "a.txt", ".env", "src/.x" }, { "src/" }, "", 100)
    -- Hidden last: dirs first, then a.txt, then the dotfiles in their order.
    assert.are.same({ "src/", "a.txt", ".env", "src/.x" }, got)
  end)
end)

describe("rank.rank fuzzy query", function()
  before_each(isolate_frecency)

  it("mixes folders and files in a single fuzzy pool", function()
    -- "inner" should match the folder "src/inner/" AND the file
    -- "src/inner/c.lua"; both should appear, ordered by score, not by type.
    local files = { "src/inner/c.lua", "src/b.lua", "other.txt" }
    local dirs = rank.derive_all_dirs(files)
    local got = rank.rank("/proj", files, dirs, "inner", 100)
    -- Both should be present.
    local saw_dir, saw_file = false, false
    for _, p in ipairs(got) do
      if p == "src/inner/" then saw_dir = true end
      if p == "src/inner/c.lua" then saw_file = true end
    end
    assert.is_true(saw_dir, "folder match should appear")
    assert.is_true(saw_file, "file match should appear")
    -- And no irrelevant items.
    for _, p in ipairs(got) do
      assert.is_truthy(p:lower():find("inner", 1, true), "every result matches the query: " .. p)
    end
  end)

  it("gives a prefix-match bonus", function()
    -- "src/a.lua" begins with "src", "x/src/y.lua" contains it. Prefix wins.
    local files = { "x/src/y.lua", "src/a.lua" }
    local got = rank.rank("/proj", files, {}, "src", 100)
    assert.equals("src/a.lua", got[1])
  end)

  it("ranks a folder above its longer descendant file for the same fuzzy query", function()
    -- This is the behavior the length penalty + folder bonus exist to produce.
    -- matchfuzzy alone would tie these (same matched chars, same bonuses) and
    -- input order would put the file first.
    local files = { "src/inner/foo.lua", "other/thing.lua" }
    local dirs = rank.derive_all_dirs(files)
    local got = rank.rank("/proj", files, dirs, "inner", 100)
    assert.equals("src/inner/", got[1])
  end)

  it("frecency multiplies the score so recents float up", function()
    local files = { "src/a.lua", "src/b.lua" }
    -- Without frecency the matchfuzzy order is stable but not necessarily
    -- ours, so seed b.lua heavily and assert it wins.
    frecency.update("/proj/src/b.lua")
    frecency.update("/proj/src/b.lua")
    frecency.update("/proj/src/b.lua")
    local got = rank.rank("/proj", files, {}, "src", 100)
    assert.equals("src/b.lua", got[1])
  end)
end)
