local files = require("filemention.files")

local function tmpdir_with(entries)
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  for _, rel in ipairs(entries) do
    local full = dir .. "/" .. rel
    vim.fn.mkdir(vim.fn.fnamemodify(full, ":h"), "p")
    local f = assert(io.open(full, "w"))
    f:write("x"); f:close()
  end
  return dir
end

local function wait_for(predicate, timeout_ms)
  local ok = vim.wait(timeout_ms or 1000, predicate, 10)
  return ok
end

describe("files.list", function()
  it("vim backend returns files under root", function()
    local dir = tmpdir_with({ "a.txt", "nested/b.txt" })
    local opts = {
      root = function() return dir end,
      respect_gitignore = true,
      include_hidden = false,
      max_items = 100,
      finder = "vim",
    }
    local got
    files.list(opts, nil, function(_, paths) got = paths end)
    assert(wait_for(function() return got ~= nil end))
    table.sort(got)
    assert.is_true(#got >= 2, "expected at least 2 files, got " .. #got)
  end)

  it("falls back when finder=fff but fff is unavailable", function()
    -- No fff.core on the rtp in headless tests, so this exercises the
    -- silent-fallback path.
    local dir = tmpdir_with({ "only.txt" })
    local opts = {
      root = function() return dir end,
      respect_gitignore = true,
      include_hidden = false,
      max_items = 10,
      finder = "fff",
    }
    local got, ordered_seen
    files.list(opts, "only", function(_, paths, ordered)
      got, ordered_seen = paths, ordered
    end)
    assert(wait_for(function() return got ~= nil end))
    assert.is_false(ordered_seen, "fallback path must not claim ordered results")
    assert.is_true(#got >= 1)
  end)
end)

describe("files.list with stubbed fff", function()
  before_each(function()
    package.loaded["fff.core"] = { is_file_picker_initialized = function() return true end }
    package.loaded["fff.file_picker"] = {
      state = { initialized = true },
      setup = function() return true end,
      search_files = function(query, _current, _max)
        return {
          { relative_path = "first_" .. query .. ".lua" },
          { relative_path = "second.lua" },
        }
      end,
    }
    package.loaded["filemention.files"] = nil
  end)
  after_each(function()
    package.loaded["fff.core"] = nil
    package.loaded["fff.file_picker"] = nil
    package.loaded["filemention.files"] = nil
  end)

  it("passes the query through and reports ordered=true", function()
    local files_mod = require("filemention.files")
    local opts = {
      root = function() return "/tmp" end,
      respect_gitignore = true,
      include_hidden = false,
      max_items = 10,
      finder = "fff",
    }
    local got, ordered_seen
    files_mod.list(opts, "needle", function(_, paths, ordered)
      got, ordered_seen = paths, ordered
    end)
    assert.is_true(ordered_seen)
    assert.equals("first_needle.lua", got[1])
    assert.equals("second.lua", got[2])
  end)
end)
