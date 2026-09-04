-- Native gc/gcc (built into Neovim 0.10+) already reads 'commentstring'.
-- This plugin makes that context-aware inside multi-language buffers
-- (e.g. JS/CSS embedded in a Vue SFC) by updating 'commentstring' per
-- treesitter node under the cursor.
return {
  "JoosepAlviste/nvim-ts-context-commentstring",
  lazy = false,
  opts = {
    enable_autocmd = false,
  },
  config = function(_, opts)
    require("ts_context_commentstring").setup(opts)
    vim.g.skip_ts_context_commentstring_module = true
  end,
}
