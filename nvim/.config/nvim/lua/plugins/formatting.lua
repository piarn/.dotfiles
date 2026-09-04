return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true })
      end,
      desc = "Format buffer",
    },
  },
  opts = {
    formatters_by_ft = {
      go = { "goimports", "gofumpt" },
      python = { "ruff_format" },
      lua = { "stylua" },
      c = { "clang_format" },
      rust = { "rustfmt" },
      nim = { "nimpretty" },
      sh = { "shfmt" },
    },
    format_on_save = {
      timeout_ms = 500,
      lsp_format = "fallback",
    },
  },
}
