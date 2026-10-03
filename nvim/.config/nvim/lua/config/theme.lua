-- Theme (~/.rice) — editor chrome only, code syntax colors untouched.
-- See ~/.rice/nvim/theme.lua for exactly what it does and doesn't set.
local rice_theme = vim.fn.expand("~/.rice/nvim/theme.lua")

local M = {}

-- Neutral stand-ins for when ~/.rice isn't there (fresh machine, ssh box).
local fallback = {
  black = "#101010", surface = "#1c1c1c", fg = "#e0e0e0", white = "#ffffff",
  neon = "#9a9a9a", acid = "#c0c0c0", dim = "#3a3a3a", deep = "#262626",
  gray = "#5a5a5a", gray2 = "#7a7a7a", red = "#d75f5f", amber = "#d7af5f",
  blue = "#5f87d7", magenta = "#d75fd7", cyan = "#5fd7d7",
}

local function load()
  local ok, theme = pcall(dofile, rice_theme)
  if ok and type(theme) == "table" then
    return theme
  end
end

-- The rice palette (theme.toml's [colors]), with fallbacks for any key the
-- rendered theme doesn't export.
function M.colors()
  local theme = load()
  return vim.tbl_extend("force", fallback, theme and theme.colors or {})
end

-- lualine theme from the palette: the mode block carries the mode's color,
-- the rest sits on the background like tmux's status bar.
function M.lualine()
  local c = M.colors()
  local function mode(color)
    return {
      a = { fg = c.black, bg = color, gui = "bold" },
      b = { fg = c.fg, bg = c.surface },
      c = { fg = c.gray2, bg = c.black },
    }
  end
  return {
    normal = mode(c.neon),
    insert = mode(c.acid),
    visual = mode(c.magenta),
    replace = mode(c.red),
    command = mode(c.amber),
    terminal = mode(c.cyan),
    inactive = {
      a = { fg = c.gray, bg = c.black },
      b = { fg = c.gray, bg = c.black },
      c = { fg = c.gray, bg = c.black },
    },
  }
end

-- bufferline's `highlights` option: selected buffer in the accent, the rest dim.
function M.bufferline()
  local c = M.colors()
  local bg = { bg = c.black }
  local sel = { fg = c.neon, bg = c.surface, bold = true, italic = false }
  return {
    fill = bg,
    background = { fg = c.gray, bg = c.black },
    buffer_visible = { fg = c.gray2, bg = c.black },
    buffer_selected = sel,
    separator = { fg = c.dim, bg = c.black },
    separator_visible = { fg = c.dim, bg = c.black },
    separator_selected = { fg = c.dim, bg = c.surface },
    indicator_selected = { fg = c.neon, bg = c.surface },
    modified = { fg = c.amber, bg = c.black },
    modified_visible = { fg = c.amber, bg = c.black },
    modified_selected = { fg = c.amber, bg = c.surface },
    duplicate = { fg = c.gray, bg = c.black, italic = true },
    duplicate_selected = { fg = c.gray2, bg = c.surface, italic = true },
    error = { fg = c.gray, bg = c.black },
    error_selected = { fg = c.red, bg = c.surface, bold = true },
    error_diagnostic = { fg = c.red, bg = c.black },
    error_diagnostic_selected = { fg = c.red, bg = c.surface },
    warning = { fg = c.gray, bg = c.black },
    warning_selected = { fg = c.amber, bg = c.surface, bold = true },
    warning_diagnostic = { fg = c.amber, bg = c.black },
    warning_diagnostic_selected = { fg = c.amber, bg = c.surface },
    offset_separator = { fg = c.dim, bg = c.black },
  }
end

local function apply()
  local theme = load()
  if theme and theme.setup then
    theme.setup()
  end
end

apply()

vim.api.nvim_create_autocmd("ColorScheme", {
  desc = "Reapply ~/.rice theme on top of any colorscheme change",
  callback = apply,
})

-- The Cursor highlight group above makes nvim push its color into the
-- terminal via OSC 12 while running. Without this, that color stays latched
-- in the pty after nvim quits and wins over kitty/foot's own cursor color
-- (both explicitly say a program-set cursor color takes precedence over
-- their own config) — so a shell that's had nvim open in it keeps showing
-- a stale cursor color across theme switches until the escape code is
-- reset. OSC 112 is the "reset cursor color to terminal default" sequence.
vim.api.nvim_create_autocmd("VimLeave", {
  desc = "Release the OSC 12 cursor color back to the terminal on exit",
  callback = function()
    io.write("\27]112\7")
    io.flush()
  end,
})

return M
