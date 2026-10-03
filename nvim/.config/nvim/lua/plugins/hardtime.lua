-- Breaks bad habits: hjkl/arrow spam is blocked after a few repeats and a hint
-- names the better motion. ␣uh toggles it for the session.
return {
  "m4xshen/hardtime.nvim",
  event = "VeryLazy",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    disable_mouse = false, -- the mouse stays (tmux and sway use it too)
    restriction_mode = "block",
    max_count = 3,
    disabled_filetypes = {
      "neo-tree", "aerial", "trouble", "dap-view", "dap-repl", "dap-view-term",
      "lazy", "mason", "qf", "help", "checkhealth", "fzf", "TelescopePrompt",
    },
  },
}
