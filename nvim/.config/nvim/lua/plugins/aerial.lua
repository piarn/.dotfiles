-- Symbol outline, right. ␣o toggles; inside it, Enter jumps, { } move between symbols.
return {
  "stevearc/aerial.nvim",
  cmd = { "AerialToggle", "AerialOpen", "AerialNavToggle" },
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    backends = { "lsp", "treesitter", "markdown", "man" },
    layout = {
      default_direction = "right",
      min_width = 28,
      max_width = { 40, 0.25 },
    },
    attach_mode = "global", -- follows whichever buffer has focus
    show_guides = true,
    filter_kind = false, -- all symbol kinds, not just functions/classes
  },
}
