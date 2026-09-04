# vim-modes

Vim's mode model for tmux: every client is in NORMAL, VISUAL or INSERT, the
current mode shows on the status bar, and Escape is how you leave a mode.

Load it after TPM's `run`, so its copy-mode bindings win over tmux-yank's:

```tmux
set -g prefix Space
run '~/.config/tmux/plugins/vim-modes/vim-modes.tmux'
```

## Modes

New clients always attach in NORMAL.

| Mode | For | Entered by | Left by |
| --- | --- | --- | --- |
| NORMAL | running tmux commands | Escape (from INSERT), attach, leaving VISUAL | `<leader> i`, `<leader> v` |
| INSERT | typing into the shell; no tmux commands | `<leader> i` | Escape, `C-Space` |
| VISUAL | selecting text and yanking it; no tmux commands | `<leader> v`, drag-select, wheel-scroll | Escape, `q`, `y` |

INSERT and VISUAL are never reachable from each other by keyboard — both exit
to NORMAL first, exactly like vim. The mouse is the one exception: drag-select
and wheel-scroll open copy-mode from wherever you are, because that is what
those gestures mean; releasing or quitting still lands you in NORMAL.

Keys typed in NORMAL never reach the pane: an unbound one is swallowed rather
than passed through. In INSERT the reverse holds — there is no prefix key, so
the only keys tmux takes are Escape and `C-Space`.

Escape is forwarded untouched to panes running nvim or vim, which need it for
their own insert->normal transition; `C-Space` is the way out of INSERT there
(and anywhere else a program wants Escape for itself).

## The leader

The leader is tmux's own prefix — whatever `prefix` (and `prefix2`) is set to
when the plugin loads, so `set -g prefix Space` makes it Space. Its commands
live in tmux's real `prefix` key table, so stock bindings, other plugins'
bindings and `list-keys -T prefix` all keep working, and every one of them
returns to NORMAL when it finishes.

The plugin then sets `prefix` itself to `None`. It has to: tmux's built-in
prefix check only fires while the client is on the default key table, which
here is INSERT, so a live `prefix Space` would eat the space bar as you type.
NORMAL reaches the table through an ordinary key binding instead. Two
consequences worth knowing:

- Change the leader by setting `prefix` to another key and reloading. Deleting
  the line instead leaves the last leader in place until the server restarts,
  because by then the option reads `None` — the plugin remembers the key in
  `@vim-modes-leader`.
- `-r` repeat bindings lose their repeat, since the return to NORMAL fires
  after the first press. NORMAL's own `hjkl` covers the resizing this mattered
  for.

## Keys

NORMAL, direct:

- `h` `j` `k` `l` — move to the pane left/down/up/right. Over a vim or nvim
  pane the matching vim-tmux-navigator chord is handed over instead, so a move
  crosses into a vim split and only reaches the next tmux pane once vim runs
  out of splits that way.
- `C-h` `C-j` `C-k` `C-l` — the same, on the chord INSERT uses
- `H` `J` `K` `L` — resize the pane by 5
- the leader — below

NORMAL, after the leader:

- `i` INSERT, `v` VISUAL
- `s` split horizontally, `V` split vertically, `z` zoom
- `x` kill pane, `X` kill window (both confirm on the status line; stock `&`
  still kills the window too)
- `c` new window, `n`/`p` next/previous, `1`-`0` by index, `w` chooser, `,` rename
- `d` detach, `r` reload config, `S`/`R` resurrect save/restore
- arrows, `o` and `;` move between panes as they do in stock tmux
- everything tmux binds by default that is not listed above (`%`, `[`, `?`, `t`,
  `f`, `o`, …) still works and also returns to NORMAL

VISUAL is tmux's copy-mode with vi keys: `v` select, `V` line, `C-v` block,
`y` yank to the system clipboard (via tmux-yank).

## Options

Set before the `run` line. Text defaults carry their own padding; styles are
empty by default so a theme can own the colours.

| Option | Default |
| --- | --- |
| `@vim-modes-normal-text` | `" NORMAL "` |
| `@vim-modes-visual-text` | `" VISUAL "` |
| `@vim-modes-insert-text` | `" INSERT "` |
| `@vim-modes-normal-style` | `""` |
| `@vim-modes-visual-style` | `""` |
| `@vim-modes-insert-style` | `""` |
| `@vim-modes-escape-passthrough` | `"nvim vim"` |
| `@vim-modes-leader` | read from `prefix` |
| `@vim-modes-leader2` | read from `prefix2` |
| `@vim-modes-auto-status` | `"on"` |

With `@vim-modes-auto-status 'on'` the indicator is prepended to `status-left`.
Set it to `off` to place it yourself — the format is published as a user
option, so it needs the double-expansion modifier:

```tmux
set -g status-left "#{E:@mode_indicator} [#S] "
```

## Notes

The whole design turns on two facts about tmux key tables, both of which are
easy to get backwards; `vim-modes.conf`'s header documents them in full.

- `switch-client -T` holds for exactly one keypress before falling back to the
  `key-table` option, so the sticky mode has to be the default table (root =
  INSERT) and every binding in a non-default table has to re-arm it.
- copy-mode's key table is only consulted while the client is on its *default*
  key table, so VISUAL runs on root and is detected from `pane_in_mode`, which
  also makes the chooser and clock modes read as VISUAL rather than as INSERT.
  Returning
  to NORMAL on the way out is done with a `pane-mode-changed` hook rather than
  per-key, which also catches exits bound by other plugins.

Escape is handed to the pane, rather than switching mode, whenever the pane is
in a mode that is not copy-mode — a chooser, the clock. Those modes have no
populated key table of their own; tmux only reaches them through "unbound in
the current table, so send it to the pane", so a root-table Escape binding
would swallow their cancel key and strand the chooser open.

A session switch resets the client's key table to the default, i.e. INSERT, so
the mode is re-asserted from a `client-session-changed` hook. Without it,
tmux-continuum's auto-restore — which switches the client once per restored
session at server start — left every fresh server in INSERT a beat after the
attach hook had correctly put it in NORMAL. Session choosers and
`switch-client -n/-p` hit the same reset.

`confirm-before` suspends the rest of its command chain until the prompt is
answered, and answering with Escape drops what was still queued — so a trailing
return-to-NORMAL never ran on a cancel and left the client in INSERT. The kill
bindings therefore run the return *first*. (Unrelated tmux quirk, reproducible
on a stock `-f /dev/null` server: the confirm prompt after an Escape-cancelled
one does not take `y`. Press the key again.)

`assume-paste-time` is set to 0. Left at its 1ms default, tmux treats anything
arriving in a burst as a paste and skips key bindings for it, so text pasted
while in NORMAL is typed into the shell instead of being swallowed — 8 of 10
characters leaked in a measured 10-character burst.
