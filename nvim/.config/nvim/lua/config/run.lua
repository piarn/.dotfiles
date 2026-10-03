-- ␣r: run, build, test — per filetype. Run and test commands go to the
-- terminal panel (config/terminal.lua) so their output stays scrollable and
-- the shell stays usable. Build runs in the background and fills the quickfix
-- list, which opens in the problems panel when there's anything in it.
--
-- Each language is a table of functions taking the context below and returning
-- a shell command (or nil when it doesn't apply):
--   run, build, test_file, test_nearest
-- plus `root` (markers for the project root), `compiler` (a :compiler whose
-- 'errorformat' parses build output) or `efm`.
local M = {}

local term = require("config.terminal")

local function q(s)
  return vim.fn.shellescape(s)
end

-- Walk upward from the cursor for the first line matching `pattern` and
-- return its first capture.
local function enclosing(pattern)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, row, false)
  for i = #lines, 1, -1 do
    local name = lines[i]:match(pattern)
    if name then
      return name, i
    end
  end
end

local function has(ctx, file)
  return vim.uv.fs_stat(ctx.root .. "/" .. file) ~= nil
end

local langs = {}

langs.go = {
  root = { "go.mod" },
  compiler = "go",
  run = function(ctx) return "go run " .. q(ctx.dir) end,
  build = function() return "go build ./... && go vet ./..." end,
  test_file = function(ctx) return "go test -v " .. q(ctx.dir) end,
  test_nearest = function(ctx)
    local name = enclosing("^func%s+(Test%w*)%s*%(") or enclosing("^func%s+(Benchmark%w*)%s*%(")
    return name and ("go test -v -run " .. q("^" .. name .. "$") .. " " .. q(ctx.dir))
  end,
}

langs.python = {
  root = { "pyproject.toml", "setup.py", "requirements.txt", ".venv" },
  efm = "%f:%l:%c: %m",
  run = function(ctx) return "python3 " .. q(ctx.file) end,
  build = function() return "ruff check --output-format=concise ." end,
  test_file = function(ctx) return "python3 -m pytest -q " .. q(ctx.file) end,
  test_nearest = function(ctx)
    local name = enclosing("^%s*def%s+(test[%w_]*)%s*%(")
    return name and ("python3 -m pytest -q " .. q(ctx.file) .. " -k " .. q(name))
  end,
}

langs.rust = {
  root = { "Cargo.toml" },
  compiler = "cargo",
  run = function() return "cargo run" end,
  build = function() return "cargo build" end,
  test_file = function() return "cargo test" end,
  test_nearest = function()
    local name, line = enclosing("^%s*[%w%s()]*fn%s+([%w_]+)")
    if not name then
      return nil
    end
    local above = vim.api.nvim_buf_get_lines(0, math.max(line - 4, 0), line - 1, false)
    for _, l in ipairs(above) do
      if l:match("#%[.*test%]") then
        return "cargo test " .. q(name) .. " -- --nocapture"
      end
    end
  end,
}

local function c_like(cc)
  return {
    root = { "Makefile", "CMakeLists.txt", "compile_commands.json" },
    compiler = "gcc",
    run = function(ctx)
      if has(ctx, "Makefile") then
        return "make run"
      end
      local out = vim.fn.fnamemodify(ctx.file, ":r")
      return cc .. " -Wall -g " .. q(ctx.file) .. " -o " .. q(out) .. " && " .. q(out)
    end,
    build = function(ctx)
      if has(ctx, "Makefile") then
        return "make"
      elseif has(ctx, "CMakeLists.txt") then
        return "cmake -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON && cmake --build build"
      end
      return cc .. " -Wall -Wextra -g -fsyntax-only " .. q(ctx.file)
    end,
    test_file = function(ctx)
      if has(ctx, "CMakeLists.txt") then
        return "ctest --test-dir build --output-on-failure"
      end
      return "make test"
    end,
  }
end
langs.c = c_like("cc")
langs.cpp = c_like("c++")

langs.zig = {
  root = { "build.zig" },
  efm = "%f:%l:%c: %m",
  run = function(ctx) return has(ctx, "build.zig") and "zig build run" or ("zig run " .. q(ctx.file)) end,
  build = function(ctx) return has(ctx, "build.zig") and "zig build" or ("zig build-exe " .. q(ctx.file)) end,
  test_file = function(ctx) return "zig test " .. q(ctx.file) end,
  test_nearest = function(ctx)
    local name = enclosing('^%s*test%s+"([^"]+)"')
    return name and ("zig test " .. q(ctx.file) .. " --test-filter " .. q(name))
  end,
}

langs.nim = {
  root = { "*.nimble" },
  efm = "%f(%l\\, %c) %m",
  run = function(ctx) return "nim r " .. q(ctx.file) end,
  build = function(ctx) return "nim check " .. q(ctx.file) end,
  test_file = function() return "nimble test" end,
}

langs.lua = {
  run = function(ctx) return "lua " .. q(ctx.file) end,
}

local function js(runner)
  return {
    root = { "package.json" },
    efm = "%f(%l\\,%c): %m,%f:%l:%c - %m",
    run = function(ctx) return runner .. " " .. q(ctx.file) end,
    build = function(ctx) return has(ctx, "package.json") and "npm run build" or nil end,
    test_file = function() return "npm test" end,
  }
end
langs.javascript = js("node")
langs.typescript = js("npx tsx")

local function shell(interp)
  return {
    efm = "%f:%l:%c: %m",
    run = function(ctx) return interp .. " " .. q(ctx.file) end,
    build = function(ctx)
      if interp == "fish" then
        return "fish --no-execute " .. q(ctx.file)
      end
      return "shellcheck -f gcc " .. q(ctx.file)
    end,
  }
end
langs.sh = shell("bash")
langs.bash = shell("bash")
langs.fish = shell("fish")

local last -- the last ␣r action, for ␣rl

local function context(lang)
  local file = vim.api.nvim_buf_get_name(0)
  local dir = vim.fn.fnamemodify(file, ":p:h")
  local root = (lang.root and vim.fs.root(0, lang.root)) or vim.fn.getcwd()
  return { file = file, dir = dir, root = root }
end

local function lookup(kind)
  local ft = vim.bo.filetype
  local lang = langs[ft]
  local make = lang and lang[kind]
  if not make then
    vim.notify(("nothing to %s for '%s'"):format(kind:gsub("_", " "), ft ~= "" and ft or "this buffer"), vim.log.levels.WARN)
    return
  end
  if vim.bo.modified then
    vim.cmd("silent! write")
  end
  local ctx = context(lang)
  return lang, ctx, make(ctx)
end

-- Run `kind` (run / test_file / test_nearest) in the terminal panel.
local function in_terminal(kind)
  local _, ctx, cmd = lookup(kind)
  if not ctx then
    return
  end
  if not cmd then
    vim.notify("no test around the cursor", vim.log.levels.WARN)
    return
  end
  local line = "cd " .. q(ctx.root) .. " && " .. cmd
  last = function()
    term.send(line)
  end
  last()
end

-- The errorformat a :compiler sets, without leaving it set on the buffer.
local function compiler_efm(name)
  local efm, mp = vim.bo.errorformat, vim.bo.makeprg
  local ok = pcall(vim.cmd.compiler, name)
  local got = ok and vim.bo.errorformat or nil
  vim.bo.errorformat, vim.bo.makeprg = efm, mp
  return got
end

function M.build()
  local lang, ctx, cmd = lookup("build")
  if not ctx or not cmd then
    return
  end
  local efm = lang.efm or (lang.compiler and compiler_efm(lang.compiler)) or vim.o.errorformat
  local function go()
    vim.notify("build: " .. cmd)
    vim.system({ "sh", "-c", cmd }, { cwd = ctx.root, text = true }, function(res)
      vim.schedule(function()
        local out = (res.stdout or "") .. (res.stderr or "")
        local lines = vim.split(out, "\n", { trimempty = true })
        vim.fn.setqflist({}, " ", { title = cmd, lines = lines, efm = efm })
        local items = vim.tbl_filter(function(i)
          return i.valid == 1
        end, vim.fn.getqflist())
        if #items > 0 then
          require("trouble").open({ mode = "qflist", focus = false })
          vim.notify(("build: %d problem(s)"):format(#items), vim.log.levels.WARN)
        elseif res.code ~= 0 then
          vim.notify("build failed (exit " .. res.code .. "):\n" .. table.concat(vim.list_slice(lines, math.max(#lines - 10, 1)), "\n"), vim.log.levels.ERROR)
        else
          pcall(require("trouble").close, { mode = "qflist" })
          vim.notify("build: ok")
        end
      end)
    end)
  end
  last = go
  go()
end

function M.run()
  in_terminal("run")
end

function M.test(scope)
  in_terminal(scope == "nearest" and "test_nearest" or "test_file")
end

function M.last()
  if last then
    last()
  else
    vim.notify("nothing run yet", vim.log.levels.WARN)
  end
end

return M
