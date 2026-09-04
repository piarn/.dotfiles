return {
  {
    "mason-org/mason.nvim",
    opts = {},
  },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = {
      ensure_installed = {
        "gopls",
        "basedpyright",
        "ruff",
        "lua_ls",
        "clangd",
        "bashls",
        "yamlls",
        "jsonls",
        "rust_analyzer",
        "nim_langserver",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = event.buf, desc = desc })
          end

          map("gd", vim.lsp.buf.definition, "Goto definition")
          map("gr", vim.lsp.buf.references, "Goto references")
          map("gI", vim.lsp.buf.implementation, "Goto implementation")
          map("gD", vim.lsp.buf.type_definition, "Type definition")
          map("K", vim.lsp.buf.hover, "Hover documentation")
          map("<leader>rn", vim.lsp.buf.rename, "Rename")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
        end,
      })

      -- lua_ls: recognize the vim global so config files don't warn
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
          },
        },
      })

      -- ruff: use for linting/actions, defer formatting to conform.nvim
      vim.lsp.config("ruff", {
        init_options = {
          settings = { organizeImports = true },
        },
      })

      vim.diagnostic.config({
        virtual_text = true,
        severity_sort = true,
      })
    end,
  },
}
