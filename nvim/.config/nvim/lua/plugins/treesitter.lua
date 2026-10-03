-- The `main` branch: the maintained rewrite for Neovim 0.12. It only installs
-- parsers; highlighting is Neovim's own vim.treesitter.start, turned on per
-- buffer below. Parsers build with the tree-sitter CLI (packages.txt).
local parsers = {
  "go", "gomod", "gowork", "gosum",
  "python",
  "lua", "luadoc",
  "c", "cpp",
  "rust",
  "zig",
  "nim",
  "javascript", "typescript", "tsx",
  "bash", "fish",
  "yaml", "json", "toml",
  "dockerfile",
  "diff", "gitcommit",
  "vim", "vimdoc", "query",
  "markdown", "markdown_inline",
}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false, -- the main branch doesn't support lazy-loading
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install(parsers)

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter-start", { clear = true }),
        desc = "Treesitter highlight + indent where a parser exists",
        callback = function(ev)
          if not pcall(vim.treesitter.start, ev.buf) then
            return
          end
          vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
  {
    -- af/if, ]f/[f ... — the keys themselves are in config/keymaps.lua
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    lazy = false,
    opts = {
      select = { lookahead = true },
      move = { set_jumps = true },
    },
  },
}
