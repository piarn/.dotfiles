-- lua/tree.lua
require('nvim-tree').setup({
  -- NvimTree setup options go here
  update_focused_file = {
    enable = true,
    update_cwd = true,
  },
  view = {
    width = 50,  -- Set the width of the file explorer
    side = 'right' -- open nvim tree on the right side
  },
})

