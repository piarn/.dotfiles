-- Buffer tabs, top. [b / ]b move between them (Neovim's own), ␣w closes one.
return {
  "akinsho/bufferline.nvim",
  version = "*",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = function()
    return {
      options = {
        mode = "buffers",
        diagnostics = "nvim_lsp",
        show_buffer_close_icons = false,
        show_close_icon = false,
        separator_style = "thin",
        always_show_bufferline = true,
        offsets = {
          { filetype = "neo-tree", text = "project", highlight = "Directory", separator = true },
        },
      },
      highlights = require("config.theme").bufferline(),
    }
  end,
}
