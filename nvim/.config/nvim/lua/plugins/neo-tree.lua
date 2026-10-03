-- Project tree, left. ␣e toggles, ␣E reveals the current file (config/keymaps.lua).
return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  lazy = false, -- neo-tree defers its own loading; eager so `nvim <dir>` opens it
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    close_if_last_window = true,
    popup_border_style = "single",
    enable_git_status = true,
    enable_diagnostics = true,
    window = {
      position = "left",
      width = 32,
      mappings = {
        -- hjkl-ish: l opens, h closes the folder; the rest are neo-tree's (? lists them)
        ["l"] = "open",
        ["h"] = "close_node",
        ["<space>"] = "none", -- leave the leader alone inside the tree
      },
    },
    filesystem = {
      hijack_netrw_behavior = "open_current",
      use_libuv_file_watcher = true,
      filtered_items = {
        visible = true, -- dotfiles shown, dimmed
        hide_dotfiles = false,
        hide_gitignored = true,
        never_show = { ".git" },
      },
    },
    default_component_configs = {
      indent = { with_expanders = true },
      git_status = {
        symbols = {
          added = "+", modified = "~", deleted = "-", renamed = "»",
          untracked = "?", ignored = "◌", unstaged = "", staged = "✓", conflict = "!",
        },
      },
    },
  },
}
