return {
  "saghen/blink.cmp",
  event = "InsertEnter",
  version = "*",
  opts = {
    -- default preset: Ctrl+y accept, Ctrl+n/p move, Ctrl+e close, Ctrl+k
    -- signature. Its Ctrl+Space (open menu) is dropped: tmux's vim-modes owns
    -- that chord, so nvim never sees it — the menu opens on its own anyway.
    keymap = { preset = "default", ["<C-space>"] = false },
    completion = {
      documentation = { auto_show = true },
    },
    signature = { enabled = true },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
  },
}
