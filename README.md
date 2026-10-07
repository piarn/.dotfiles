<div align="center">
<pre>
   ██████╗  ██████╗ ████████╗███████╗
   ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝
   ██║  ██║██║   ██║   ██║   ███████╗
   ██║  ██║██║   ██║   ██║   ╚════██║
██╗██████╔╝╚██████╔╝   ██║   ███████║
╚═╝╚═════╝  ╚═════╝    ╚═╝   ╚══════╝</pre>
</div>

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
(apt/dnf/pacman) and `.bootstrap/flatpaks.txt` (Flathub apps, system-wide),
then symlinks each package into `$HOME`. Anything already sitting at a
target path (e.g. a distro's default `~/.bashrc`) is moved aside into
`~/.local/state/dots/backup/<timestamp>/` first, so the repo version always
wins and the old file is kept for reference. Finally it runs
`dots-reload`, which pushes the new configs into whatever is already
running (tmux server, kitty, sway, quickshell); run it by hand, or pick
"reload" in the command center, any time a config changes under a running
session.

Tested distro families: Fedora (dnf), Debian/Ubuntu (apt), Arch (pacman).
On Arch, three of the VPN extras (`mullvad`, `netbird`, `protonvpn`) and
`ssh-vpn`'s NetworkManager plugin only have a community AUR package, no
official one — `extras/*/setup.sh` needs `yay` or `paru` already on PATH
for those specifically and fails with instructions if neither is found;
it never installs one for you. Everything else (the base desktop stack,
`tailscale`, `zerotier`, `openconnect`/`openvpn`/`vpnc`/`wireguard`) has
an official package on all three and needs nothing extra.

Quickshell itself is the one exception to "install from the distro's
package manager": `install_quickshell()` in `install.sh` builds it from
source, pinned to one git tag (`QUICKSHELL_VERSION`), the same on every
distro — it ships no prebuilt binary, has no official Ubuntu package at
all, and Fedora/Debian/Arch each package a different point release, which
risks breaking the QML API this whole desktop is built against. Costs a
handful of `-devel` build dependencies and a few minutes compiling on a
fresh install; a version marker at `~/.local/share/dots-quickshell-version`
makes re-runs a no-op until `QUICKSHELL_VERSION` is bumped.

`.bootstrap/` holds machine-setup helpers `install.sh` drives: system
packages (`packages.txt`) and the one-time fish plugin-manager setup
(`fish/install_fisher.sh`, `fish/install_bass.sh` — normally a no-op since
the resulting plugin files are committed under `fish/.config/fish`). A few
`packages.txt` entries install a binary whose name doesn't match the
package name (`ripgrep`→`rg`, `neovim`→`nvim`, `wl-clipboard`→`wl-copy`,
`pulseaudio-utils`→`pactl`) or a differently-cased package name on apt —
`install.sh` handles both via small override maps near the top.

`yazi`, `lazygit`, `lazydocker`, `satty` and `mise` aren't packaged for
apt/dnf (and `tree-sitter`, which nvim builds its parsers with, is too old on
Debian/Ubuntu), so `install.sh` downloads each from its project's GitHub releases
into `~/.local/bin` instead, pinned to the tag in `RELEASE_VERSIONS` (bump
it and re-run to upgrade; skipped if installed some other way — e.g.
`lazydocker` via `go install`).

### Checking a machine

```
./install.sh --doctor
```

Read-only: lists what `install.sh` would still install or link (via
stow's dry run), links in `$HOME` left dangling by files since removed from
a package (a normal `install.sh` run deletes those), and — inside sway —
which session services aren't running, and whether tmux, sway or
quickshell are running an older config than the one on disk (fix: run
`dots-reload`). Exits 1 if anything failed.

### When things break

- **quickshell's config doesn't load:** `qs-watchdog` runs the last config
  that did (`~/.local/state/dots/quickshell-good`) and says so in a
  swaynag. Fix the config and run `dots-reload quickshell`; once it loads,
  the fallback is stopped.
- **Locking:** everything locks through `dots-lock`, which uses swaylock
  when quickshell's lock screen doesn't come up.
- **sway dies at startup:** `sway-session` retries once with the stock
  `/etc/sway/config` (safe mode); see `~/.local/state/sway.log`. If that
  fails too you're back at the login screen, where GNOME still works.
  `dots-reload` won't reload a sway config that fails `sway -C`.
- **The session is wedged:** switch to a TTY (Ctrl+Alt+F3) or ssh in and
  run `dots-rescue` for the options (restart or roll back quickshell,
  reload or exit sway, get a swaylock prompt).

CI (`.github/workflows`) runs shellcheck and `fish --no-execute` over the
repo on every push, and `./install.sh --ci` in fresh Fedora, Debian,
Ubuntu 24.04 and Arch containers whenever the installer changes (and
weekly): every package, the polkit agent, the release-binary tools and a
full quickshell build — the parts that break when a distro renames or
drops a package.

## .rice

This repo owns *configs*; [`~/.rice`](https://github.com/piarn/.rice) owns
the *styling* layer several of them include or symlink from — sway's
colors/gaps/screen-layout, tmux/nvim/fish accents, and the
yazi/lazygit/lazydocker/firefox/KDE-app theme files. `install.sh` clones
it to `~/.rice` over https if it isn't already there (pushes go over
ssh), fast-forwards it when its branch has an upstream (a local-only
branch is left alone), renders the current theme
(`~/.rice/bin/apply-theme`), and — if sway is already running — applies
whichever screen layout matches what's connected
(`~/.rice/bin/apply-layout --auto`). Both are safe to re-run any time; see
`~/.rice/README.md` for how theming and screen layouts actually work.

## tmux

Vim-style modes, one session per "case" with persistence across reboots, a
session/window/pane tree popup, and direct Alt binds — see
[`tmux/README.md`](tmux/README.md).

## nvim

A terminal Zed whose editing language is vim: Space-leader grammar mirroring
tmux and sway (one file, `lua/config/keymaps.lua`), toggleable tree / outline /
problems / terminal panels, run-build-test per language, a debugger with a
modal stepping layer, and hardtime breaking hjkl habits — see
[`nvim/README.md`](nvim/README.md).

## Desktop

sway + [quickshell](quickshell/.config/quickshell): one 600px **island**
centered at the top of each screen (workspaces · clock · status) that grows
into tabs — system, calendar, notifications, network, run (the command
center) and clipboard — plus the lock screen and notification toasts.
Click the clock for the calendar, the status for system, `●` for
notifications; inside, `h`/`l` or Ctrl+Tab switch tabs, Esc or a click
outside collapses it. The rule: `$mod`+letter is
the everyday action, `$mod+Shift` is the bigger version (move, capture,
system). Plain Alt is left to apps.

Weather (the bar's clock pill and the lock screen) is for one fixed city,
set per machine and kept out of the repo:
`echo city=Vilnius > ~/.config/dots/weather.conf`. `dots-weather.timer`
fetches it from Open-Meteo every 30 minutes; without that file it stays
hidden.

| Keys | Action |
| --- | --- |
| `$mod+Return` / `$mod+Shift+Return` | terminal (kitty) / quick terminal (foot) |
| `$mod+Space` / `$mod+d` | the island's run tab, the command center (either key) |
| `$mod+q` | close window |
| `$mod+v` | the island's clipboard tab (cliphist history) |
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
| `$mod+Shift+Escape` | command center: `:` session mode (lock, suspend, logout, reboot, shutdown) |
| `$mod+Shift+c` | reload sway and restart quickshell |

The command center is a search box and a short list: apps, most-used
first, ranked by name/description/keywords ("pdf" finds Zathura). A
leading character switches to a mode:

| Prefix | Mode |
| --- | --- |
| `=` | calculator (`=2^10*3`, `sqrt`, `pi`); Enter copies the result |
| `>` | shell command; Enter runs it in kitty, Shift+Enter in the background |
| `/` | files under `~` via fd (empty: recently opened); Shift+Enter shows it in Dolphin |
| `?` | web search (or open an address) |
| `@` | switch to an open window |
| `~` | dev: tmux sessions (running and frozen), git projects, ssh hosts from `~/.ssh/config`; Enter opens one as a tmux session (`tmux-open`) in the terminal already showing tmux, or a new kitty |
| `!` | tools: region screenshot, screen recording, color picker (`color-pick`), clipboard history, notifications, silence |
| `:` | session: lock, reload, suspend, logout, reboot, shutdown (the last three need Enter twice); `:theme <name>`, `:layout <name>` |

Keys: ↑↓ or `^j`/`^k` move, Enter acts, Esc closes. The mouse works
everywhere too.

`qs ipc call commandcenter toggle` opens/closes it; `commandcenter open
'<text>'` opens it pre-typed, e.g. `'@'` to bind a key straight to the
window switcher, or `':'` straight to session actions.

The command center is the island's run tab. The system tab is the
mouse-first glance of the same things (plus the tray, media and battery),
and the other tabs hold the deep views (enterprise/hidden Wi-Fi, VPN
details, calendar, notifications).

Background services run as systemd user services under
`dots-session.target` (`sway/.config/systemd/user`), started once sway has
exported its environment and stopped when it exits: the polkit agent
(`mate-polkit`, password prompts), swayidle (lock after 10 minutes idle and
before sleep), cliphist, udiskie, the bluetooth agent, `layout-watch` and
`qs-watchdog`. A dead one is restarted; `journalctl --user -u <name>` has
its log, and `./install.sh --doctor` flags any that aren't running.

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

### Languages

One extra per language, each just a `setup.sh` that installs the distro's
toolchain plus the editor tooling (nothing is linked into `$HOME`):

| Extra | What it adds |
| --- | --- |
| `c` | gcc, clang, make, cmake, gdb, clangd |
| `go` | Go, plus `gopls` and `dlv` via `go install` (into `$(go env GOPATH)/bin`) |
| `json` | jq (nvim formats JSON with it) |
| `lua` | Lua 5.4, LuaJIT, luarocks |
| `nim` | Nim + nimble + `nimlangserver`; Fedora has no Nim package, so there it comes from choosenim into `~/.nimble/bin` (update: `choosenim update stable`) |
| `node` | Node.js + npm |
| `python` | Python 3 with pip/venv/headers, pipx, uv |
| `rust` | rustc, cargo, rust-analyzer |
| `yaml` | yq + yamllint (nvim formats/lints YAML with them); Debian/Ubuntu's `yq` is a different tool, so there only yamllint |
| `zig` | Zig (packaged on Fedora/Arch; Debian/Ubuntu depends on the release) |

### backup

`extras.sh enable backup` installs restic and a daily `backup.timer`
snapshotting `~` (minus caches, Steam, toolchains, `node_modules` — see
`extras/backup/home/.config/backup/excludes`), then keeps 7 daily, 4
weekly and 12 monthly snapshots. Per machine, in `~/.config/backup/`:
`env` (where to — a disk, `sftp:host:/path`, any restic backend — and
what to keep) and a generated `password`: **keep a copy of it elsewhere**,
the backup is unreadable without it. Then once: `backup init`.

`backup` with no arguments runs a backup like the timer does; anything else
goes to restic with the repository filled in: `backup snapshots`,
`backup restore latest --target /tmp/r --include ~/notes`,
`backup mount ~/mnt`. A failed run sends a notification.

Extras can ship systemd timers (`home/.config/systemd/user/*.timer`);
`extras.sh` enables them on `enable` and disables them on `disable`.

### nvidia

For sway on the proprietary NVIDIA driver. `extras.sh enable nvidia`
makes sure sway is at least 1.12: on Fedora 44 (sway 1.11) it rebuilds
Fedora's next-release sway package and installs it over the stock one.
Older sways get explicit sync turned off by `sway-session` (wlroots 0.19
aborts in it), and on NVIDIA that shows up as flickering or stale screen
regions. `~/.local/state/sway.log`'s first line shows the sway version and
whether explicit sync was off. To go back: `sudo dnf downgrade sway
sway-config-upstream`.

## Git

Commits and tags are signed with the ssh key named in
`.gitconfig.identity.github` (`~/.ssh/keys/github`); for GitHub to show them
as Verified, add that key's `.pub` once more under Settings → SSH keys as
a **Signing key**. `git log --show-signature` verifies locally against
`git/.config/git/allowed_signers`. A `.gitconfig.identity.work` should set
its own `signingkey` (or `[commit] gpgsign = false`). Diffs go through
delta (git and lazygit), with histogram diffs, zdiff3 conflict markers,
rerere and prune-on-fetch on.

## Toolchains

[mise](https://mise.jdx.dev) (installed from its GitHub release) pins
go/node/python/... per project: `mise use go@1.24` in a project writes a
`mise.toml`, and fish switches versions on `cd` (`conf.d/mise.fish`).
Outside a pinned project the distro's toolchains are used as before.

## Adding a package

```
mkdir -p newpkg/.config/newtool
# add files under newpkg/... mirroring their $HOME path
```

Then add `newpkg` to the `PACKAGES` array in `install.sh`.
