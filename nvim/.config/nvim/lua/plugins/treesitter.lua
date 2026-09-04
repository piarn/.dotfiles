return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master", -- stable API; the "main" branch rewrite dropped nvim-treesitter.configs
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  main = "nvim-treesitter.configs",
  opts = {
    ensure_installed = {
      "go", "gomod", "gowork", "gosum",
      "python",
      "lua", "luadoc",
      "c",
      "rust",
      "nim",
      "bash",
      "yaml",
      "json",
      "diff",
      "vim", "vimdoc", "query",
      "markdown", "markdown_inline",
    },
    highlight = { enable = true },
    indent = { enable = true },
    textobjects = {
      select = {
        enable = true,
        lookahead = true,
        keymaps = {
          ["af"] = "@function.outer",
          ["if"] = "@function.inner",
          ["ac"] = "@class.outer",
          ["ic"] = "@class.inner",
          ["aa"] = "@parameter.outer",
          ["ia"] = "@parameter.inner",
        },
      },
      -- Note: ]c/[c are left free for gitsigns hunk navigation.
      move = {
        enable = true,
        goto_next_start = { ["]f"] = "@function.outer" },
        goto_previous_start = { ["[f"] = "@function.outer" },
      },
    },
  },
  dependencies = {
    { "nvim-treesitter/nvim-treesitter-textobjects", branch = "master" },
  },
}
