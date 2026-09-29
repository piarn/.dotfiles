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
(apt/dnf) and `.bootstrap/flatpaks.txt` (Flathub apps, system-wide), then
symlinks each package into `$HOME`. It runs with `--adopt`,
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

## tmux

Vim-style modes, one session per "case" with persistence across reboots, a
session/window/pane tree popup, and direct Alt binds — see
[`tmux/README.md`](tmux/README.md).

## Desktop

sway + [quickshell](quickshell/.config/quickshell) (bar, popups, the dots
hub, lock screen, notifications). The rule: `$mod`+letter is the everyday
action, `$mod+Shift` is the bigger version (move, capture, system). Plain
Alt is left to apps.

| Keys | Action |
| --- | --- |
| `$mod+Return` / `$mod+Shift+Return` | terminal (kitty) / quick terminal (foot) |
| `$mod+Space` | hub: the command center (see below) |
| `$mod+d` | mini runner: just apps and the prefix modes below |
| `$mod+s` | hub: system settings |
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
| `$mod+Shift+Escape` | hub: session (lock, suspend, logout, reboot, shutdown) |
| `$mod+Shift+c` | reload sway and restart quickshell |

The hub is the command center. It opens on a home screen with a live status
line, quick toggles (wi-fi, bluetooth, silence, awake, night, power profile),
what you use most, your tmux sessions and the focus timer. One search box
reaches everything across its scopes:

| Scope | What |
| --- | --- |
| apps | applications, most-used first (plus the prefix modes below) |
| dev | tmux sessions (running and frozen), git projects, ssh hosts from `~/.ssh/config`; Enter opens one as a tmux session (`tmux-open`) in the terminal already showing tmux, or a new kitty |
| system | Wi-Fi and networks, VPNs, Bluetooth and devices, volume/mic and audio devices, brightness, night light, screen layout, power profile, keep awake, session |
| style | rice themes, previewed with wallpaper and palette |
| tools | region screenshot, screen recording, color picker (`color-pick`), focus timer (shown on the bar), clipboard history, notifications |

Typing ranks all of them together, so `night` finds night light, `ember` the
theme and `firefox` the app. A scope or group name followed by a space narrows
to it: `vpn `, `theme to`, `ssh `, `dev app`.

Keys: ↑↓ or `^j`/`^k` move, Enter acts, ←→ pick a quick toggle or nudge a
volume/brightness row, Tab/Shift+Tab switch scope, Backspace on an empty box
goes back out of a list (e.g. wi-fi networks), and Esc closes. Logout, reboot
and shutdown need Enter twice. The mouse works everywhere too.

A leading character switches to a mode:

| Prefix | Mode |
| --- | --- |
| `=` | calculator (`=2^10*3`, `sqrt`, `pi`); Enter copies the result |
| `>` | shell command; Enter runs it in kitty, Shift+Enter in the background |
| `/` | files under `~` via fd (empty: recently opened); Shift+Enter shows it in Dolphin |
| `?` | web search (or open an address) |
| `@` | switch to an open window |

`qs ipc call launcher open '<text>'` opens the mini runner pre-typed, e.g. `'@'` to
bind a key straight to the window switcher; `qs ipc call hub toggle <scope>`
and `qs ipc call hub open <scope> <group>` open a scope or group.

The bar's ≡ quick settings is the mouse-first glance of the same things
(plus the tray, notifications and media), and its popups hold the deep
views (enterprise/hidden Wi-Fi, VPN details, battery).

If quickshell hangs or crashes, `qs-watchdog` restarts it within ~15s
(re-locking if the session was locked) and keeps a hung instance's log
under `~/.cache/qs-watchdog/`. `$mod+Shift+c` does the same by hand.

New files in a package need `stow -R --no-folding -t ~ <pkg>` before
they're linked in — quickshell reports a new QML file as "X is not a
type" until then.

## Extras

Opt-in features that aren't part of the base setup live under
[`extras/`](extras): `install.sh` never installs or links them on its own.
Enable them per machine:

```
~/.dots/extras/extras.sh list             # * marks the enabled ones
~/.dots/extras/extras.sh enable mullvad   # install it, link it in, restart quickshell
~/.dots/extras/extras.sh disable mullvad  # unlink it (installed packages stay)
```

The enabled list is kept in the untracked `.extras-enabled`, and
`install.sh` re-links whatever is on it. Each extra is a directory with a
`setup.sh` (installs its dependencies, idempotent) and/or a `home/` stow
package.

VPN clients are one extra each, open-source clients only. Enabling one
installs the client and its daemon; the ones with quickshell code add
themselves to the network popup's vpn section (status, connect/disconnect,
and a › panel with the client's own settings), next to NetworkManager's
VPN profiles — which is where the NM-plugin extras' profiles show up.

| Extra | What it adds |
| --- | --- |
| `mullvad` | Mullvad VPN; panel: relay location by country/city, reconnect, lockdown mode, auto-connect, account expiry |
| `netbird` | NetBird (daemon + CLI, no tray app); panel: peers, management errors, session expiry. `[connect]` opens SSO login when needed |
| `tailscale` | Tailscale, with you as its operator (no sudo for up/down); panel: login link, exit node picker, peers |
| `protonvpn` | Proton VPN's CLI (no GTK app); panel: sign in (on a kitty terminal), kill switch, connect by country / fastest |
| `zerotier` | ZeroTier One (installer signature-checked); no connect toggle — panel: node id, networks with [leave], join by network id |
| `openvpn` | NM OpenVPN plugin: `nmcli connection import type openvpn file x.ovpn` |
| `wireguard` | wireguard-tools: `nmcli connection import type wireguard file wg0.conf` |
| `openconnect` | NM openconnect plugin: AnyConnect, GlobalProtect, Fortinet, Pulse — profiles via [settings] |
| `vpnc` | NM vpnc plugin: Cisco IPsec (.pcf import) via [settings] |
| `ssh-vpn` | NM SSH plugin: a VPN over a plain SSH login, via [settings] |

`qs ipc call vpn toggle <name>` connects/disconnects a VPN extra, e.g. for
a sway bind. Adding another client: an extra whose `home/` puts a `Vpn.qml`
(a `components/VpnProvider.qml`) under `~/.config/quickshell/extras/<name>/`;
`state/ExtrasState.qml` loads it at startup.

## Adding a package

```
mkdir -p newpkg/.config/newtool
# add files under newpkg/... mirroring their $HOME path
```

Then add `newpkg` to the `PACKAGES` array in `install.sh`.
