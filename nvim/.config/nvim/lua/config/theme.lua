-- Theme (~/.rice) — editor chrome only, code syntax colors untouched.
-- See ~/.rice/nvim/theme.lua for exactly what it does and doesn't set.
local rice_theme = vim.fn.expand("~/.rice/nvim/theme.lua")

local function apply()
  local ok, theme = pcall(dofile, rice_theme)
  if ok and theme.setup then
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
