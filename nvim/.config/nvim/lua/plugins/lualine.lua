return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  opts = {
    options = {
      theme = "auto", -- follows active colorscheme; falls back to a neutral default with none set
      globalstatus = true,
    },
  },
}
