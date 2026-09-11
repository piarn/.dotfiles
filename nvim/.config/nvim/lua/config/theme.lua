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
