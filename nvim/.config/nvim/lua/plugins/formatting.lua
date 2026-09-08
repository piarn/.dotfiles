return {
  "stevearc/conform.nvim",
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
    -- format-on-save is off entirely; <leader>cf runs one of these on demand.
    formatters_by_ft = {
      go = { "goimports", "gofumpt" },
      python = { "ruff_format" },
      lua = { "stylua" },
      c = { "clang_format" },
      rust = { "rustfmt" },
      nim = { "nimpretty" },
      sh = { "shfmt" },
    },
  },
}
