# Neovim as a TUI Zed — design

Date: 2026-10-03. Status: approved ("do it").

## Intent

Turn `nvim/.config/nvim` from "text editor with LSP" into the user's own IDE
for all code work: a debloated, terminal Zed whose editing language is vim.
It has to become an extension of the mind the way the tmux config is — one
consistent, documented grammar — and it has to *teach* motions by breaking bad
habits.

Success:

1. One key grammar, mirroring tmux/sway, in one file, documented in a README.
2. Zed-like toggleable panels: tree (left), buffer tabs (top), outline (right),
   problems + terminal (bottom). Editor opens clean; panels on demand.
3. Debugger, build-to-problems, run/test via the terminal panel, for the
   languages in `extras/` (go, python, c, rust, zig, nim, lua, node, sh).
4. hardtime blocks hjkl/arrow spam and suggests the better motion.
5. Every new surface follows `~/.rice` (`apply-theme`). No AI tooling.

## Approach

Small focused plugins on the existing hand-rolled lazy.nvim config (approach
A). Rejected: snacks.nvim backbone (one large dependency, loses the fzf look
shared with the shell), a distro (bloat; fights the grammar).

## Structure

```
lua/config/
  options.lua   + cursorline, inlay hints on
  keymaps.lua   THE grammar: every global key, which-key group names.
                Plugin keys call require() inside functions so lazy.nvim
                still loads plugins on first use.
  lsp.lua       LspAttach + server settings + diagnostic config
  theme.lua     rice loader; exposes the rice colors for lualine/bufferline
  terminal.lua  bottom terminal panel: one persistent shell, toggle, send cmd
  run.lua       per-filetype run/build/test commands
  lazy.lua      unchanged
lua/plugins/    specs only (opts, deps), no keymaps
  + neo-tree, bufferline, aerial, trouble, hardtime, dap (nvim-dap + dap-view)
README.md       grammar rules + every key, tmux-README style
```

Treesitter moves to the `main` branch (the maintained one for 0.12):
parsers via `require("nvim-treesitter").install`, highlighting via
`vim.treesitter.start` on FileType, indent via its `indentexpr`;
textobjects `main` branch with keys in `keymaps.lua`.

mason keeps installing servers no language extra provides (basedpyright,
ruff, lua_ls, bashls, yamlls, jsonls, docker*) and debugpy; gopls, clangd,
rust_analyzer and nimlangserver come from the extras (`extras/<lang>`) and
are just enabled.

## Key grammar

Rules:

1. Vim first. Operators/motions/textobjects, `g` gotos and `[`/`]` pairs stay
   native where Neovim 0.12 already has a key.
2. `Space` + mnemonic group for everything vim lacks.
3. lowercase = do it, Shift = the bigger version (as in tmux/sway).
4. Panels are one letter after the leader.
5. `Ctrl+Space` and `Ctrl+h/j/k/l` belong to tmux (vim-modes, navigator).
   Alt reaches nvim (tmux is in SHELL mode while editing).

Native, kept: `gd` `grr` `gri` `grt` `gra` `grn` `K` `gO` `[d ]d` `[b ]b`
`[q ]q` `[c ]c` (hunks) `[f ]f` (functions) `af if ac ic aa ia` `s`/`S`
(flash) `gc` (comment) `ys ds cs` (surround).

| Key | Action |
| --- | --- |
| `␣␣` `␣/` `␣:` `␣,` | find file, grep, command palette, buffers |
| `␣e` / `␣E` | tree toggle / reveal current file |
| `␣o` | outline |
| `␣p` / `␣P` | problems: file / project |
| `␣t` | terminal panel |
| `␣w` / `␣W` | close buffer / close all other buffers |
| `␣\` / `␣-` | split right / below |
| `␣f…` | `ff fg fw fr fs fh fc f.` (palette `␣:` = every keymap, searchable) |
| `␣c…` | `ca cr cf cd cl` |
| `␣g…` | `gg gs gS gr gp gb gd` |
| `␣r…` | `rr rb rt rT rl` |
| `␣d…` | `db dB dc dv dq`, stepping `dn ds do`, `dK` inspect, `dd` DEBUG mode |
| `␣u…` | `uh uw un ui ub ud` |

DEBUG mode = which-key's loop (hydra) mode over the `␣d` group: bare
`n s o c b K` until Esc.

blink.cmp: `Ctrl+Space` unbound (tmux owns it); menu auto-shows.

## Panels

- neo-tree: left, 32 cols, hidden files shown, git status, closes with the
  last window, opens on `nvim <dir>`.
- bufferline: buffers mode, LSP diagnostic counts, offset over neo-tree,
  colors from rice.
- aerial: right, LSP then treesitter backends.
- trouble v3: `diagnostics` (buffer / workspace), `qflist` after a build.
- terminal: bottom 30%, one persistent `$SHELL`; `␣t` toggles; `<Esc><Esc>`
  leaves terminal mode; `Ctrl+h/j/k/l` navigate out.

## Run

`run.lua` maps filetype → `{ run, build, test_file, test_nearest }`. Build
goes through `:make` (`makeprg` + `:compiler` errorformat) and opens trouble's
qflist when there are errors. Run/test commands go to the terminal panel;
`␣rl` repeats the last one. Nearest test is found by searching upward for the
language's test declaration (Go `func TestX`, Python `def test_x`, Rust
`#[test] fn x`).

## Debugger

nvim-dap + nvim-dap-view (opens on session start, closes on end).
Adapters: Go → `dlv dap`; C/C++/Rust/Zig → `lldb-dap` (asks for the program);
Python → mason's debugpy. Signs themed from rice.

## Habits

hardtime.nvim, enabled at start, default block mode with hints; mouse left
alone; disabled in panel filetypes; `␣uh` toggles.

## Theme

`~/.rice/templates/nvim/theme.lua.tmpl` gains groups for neo-tree,
bufferline-independent chrome, aerial, trouble, dap signs, hardtime and
exposes `blue magenta cyan white` too. lualine/bufferline get their palette
from `require("config.theme").colors()` so they follow `apply-theme` on the
next ColorScheme / restart, like the rest of nvim.

## Verification

Headless: `Lazy! sync`, startup without errors, every grammar key exists
(`maparg`), treesitter parsers install and highlight. Live: drive nvim in a
detached tmux session (send-keys / capture-pane) to open each panel, run a
Go build with an error into trouble, start a dlv session to a breakpoint.
