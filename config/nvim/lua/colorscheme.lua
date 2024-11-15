-- lua/colorscheme.lua
require("catppuccin").setup({
  flavour = "macchiato",  -- Choose the variant (macchiato, latte, mocha, frappe)
  background = {
    light = "latte",
    dark = "macchiato",
  },
})

-- Set the theme
vim.cmd("colorscheme catppuccin")

