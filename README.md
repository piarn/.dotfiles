# .dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level
directory (`bash`, `fish`, `foot`, ...) is a stow package whose contents
mirror `$HOME`.

## Setup

```
git clone <repo> ~/.dots
cd ~/.dots
./install.sh
```

`install.sh` installs whatever's missing from `.bootstrap/packages.txt`
(apt/dnf), then symlinks each package into `$HOME`. It runs with `--adopt`,
so any real file already sitting at a target path (e.g. an existing
`~/.bashrc`) is moved into the repo first, then symlinked back — check
`git diff` afterward and revert with `git checkout -- <file>` if the repo
version should have won.

`.bootstrap/` holds machine-setup helpers `install.sh` drives: system
packages (`packages.txt`) and the one-time fish plugin-manager setup
(`fish/install_fisher.sh`, `fish/install_bass.sh` — normally a no-op since
the resulting plugin files are committed under `fish/.config/fish`). A few
`packages.txt` entries install a binary whose name doesn't match the
package name (`ripgrep`→`rg`, `neovim`→`nvim`, `wl-clipboard`→`wl-copy`,
`pulseaudio-utils`→`pactl`) or a differently-cased package name on apt —
`install.sh` handles both via small override maps near the top.

`yazi`, `lazygit`, `lazydocker` and `satty` aren't packaged for apt/dnf at
all, so `install.sh` downloads each straight from its project's latest
GitHub release binary into `~/.local/bin` instead (skipped if already
installed some other way — e.g. `lazydocker` via `go install`).

## .rice

This repo owns *configs*; [`~/.rice`](https://github.com/piarn/.rice) owns
the *styling* layer several of them include or symlink from — sway's
colors/gaps/screen-layout, tmux/nvim/fish accents, and the
yazi/lazygit/lazydocker/firefox/KDE-app theme files. `install.sh` clones
it to `~/.rice` if it isn't already there, renders the current theme
(`~/.rice/bin/apply-theme`), and — if sway is already running — applies
whichever screen layout matches what's connected
(`~/.rice/bin/apply-layout --auto`). Both are safe to re-run any time; see
`~/.rice/README.md` for how theming and screen layouts actually work.

## Desktop

sway + [quickshell](quickshell/.config/quickshell) (bar, popups, launcher,
lock screen, notifications). The rule: `$mod`+letter is the everyday
action, `$mod+Shift` is the bigger version (move, capture, system). Plain
Alt is left to apps.

| Keys | Action |
| --- | --- |
| `$mod+Return` / `$mod+Shift+Return` | terminal (kitty) / quick terminal (foot) |
| `$mod+Space` (or `$mod+d`) | launcher (see below) |
| `$mod+q` | close window |
| `$mod+v` | clipboard history (cliphist) |
| `$mod+e` | file manager (Dolphin) |
| `$mod+b` | browser (Firefox) |
| `$mod+h/j/k/l`, arrows | focus; add Shift to move the window |
| `$mod+1`–`0` | workspace; add Shift to send the window there |
| `$mod+t` | toggle split direction (side by side ↔ stacked) |
| `$mod+w` | toggle tabbed ↔ tiled |
| `$mod+f` / `$mod+Shift+f` | maximize / fullscreen |
| `$mod+Shift+t` | toggle floating |
| `$mod+Tab` | focus between tiled and floating windows |
| `$mod+a` | focus parent container |
| `$mod+r` | resize mode (hjkl/arrows, Enter or Esc to leave) |
| `$mod+minus` / `$mod+Shift+minus` | show / send to scratchpad |
| `$mod+Shift+s` | region screenshot: frozen screen in satty, crop, Enter saves + copies |
| `$mod+Shift+r` | start/stop screen recording to `~/Videos/Captures` (click a window, drag a region, or click a monitor's bar) |
| `$mod+Escape` | lock |
| `$mod+Shift+Escape` | power menu (incl. logout) |
| `$mod+Shift+c` | reload sway and restart quickshell |

The launcher searches apps by name, description and keywords ("pdf" finds
Zathura), most-used first. A leading character switches mode:

| Prefix | Mode |
| --- | --- |
| `=` | calculator (`=2^10*3`, `sqrt`, `pi`); Enter copies the result |
| `:` | system actions: lock, reload, suspend, logout, reboot, shutdown, `:theme <name>`, `:layout <name>` |
| `>` | shell command; Enter runs it in kitty, Shift+Enter in the background |
| `/` | files under `~` via fd (empty: recently opened); Shift+Enter shows it in Dolphin |
| `?` | web search (or open an address) |
| `@` | switch to an open window |

`qs ipc call launcher open '<text>'` opens it pre-typed, e.g. `'@'` to
bind a key straight to the window switcher.

Everything else (Wi-Fi incl. enterprise/hidden networks, Bluetooth, audio
devices, night light, keep awake, power profile, tray) lives in the bar's
popups and the ≡ quick settings.

If quickshell hangs or crashes, `qs-watchdog` restarts it within ~15s
(re-locking if the session was locked) and keeps a hung instance's log
under `~/.cache/qs-watchdog/`. `$mod+Shift+c` does the same by hand.

New files in a package need `stow -R --no-folding -t ~ <pkg>` before
they're linked in — quickshell reports a new QML file as "X is not a
type" until then.

## Adding a package

```
mkdir -p newpkg/.config/newtool
# add files under newpkg/... mirroring their $HOME path
```

Then add `newpkg` to the `PACKAGES` array in `install.sh`.
