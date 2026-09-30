# Session fallbacks

## Goal

When quickshell or sway breaks, the session degrades to something usable
instead of leaving no bar, no lock screen, or no session at all. Four
failures, each with its own fallback:

1. quickshell's config fails to load (bad edit/merge, a missing file).
2. The lock screen can't come up: locking, or re-locking after quickshell
   dies while locked, with no working lock client.
3. sway dies at startup, so GDM drops straight back to the login screen.
4. The session is hung or unusable, and a TTY or ssh is the only way in.

Out of scope: preventing bad edits in general (a quickshell trial-load
before restart), Magic SysRq (the keyboard has no Print key), a manual
"safe mode" session entry at GDM (the automatic retry in 3 covers it).

## Facts this relies on

- `qs ipc call` exits 0 even when the target doesn't exist ("Target not
  found."), e.g. a running quickshell whose config failed to load. It exits
  non-zero only when no instance is running at all. So the IPC exit code
  can't tell whether locking worked.
- LockScreen.qml writes `1`/`0` to `$XDG_RUNTIME_DIR/quickshell-locked` on
  every lock state change. That's the proof the lock actually engaged.
- quickshell's per-instance log
  (`$XDG_RUNTIME_DIR/quickshell/by-pid/<pid>/log.log`) contains
  `Configuration Loaded` or `Failed to load configuration`.
- sway 1.11 lets a new lock client take over after the previous one died
  while locked (the watchdog's existing re-lock depends on this).
- `sway --unsupported-gpu -C` validates a config (syntax, not command
  semantics or missing includes). Without `--unsupported-gpu` it always
  fails on the NVIDIA machine.
- swaylock is installed and ships its own `/etc/pam.d/swaylock`.
- `/usr/local/bin/sway-session` (GDM's Sway entry, via
  `/usr/local/share/wayland-sessions/sway.desktop`) isn't in the repo yet.

## Design

### 1. quickshell: last-good config (qs-watchdog)

- After a quickshell instance's log says `Configuration Loaded`, the
  watchdog snapshots the config it loaded into
  `~/.local/state/dots/quickshell-good/` (`cp -rL` of `~/.config/quickshell`,
  resolving the stow symlinks; about 60 files / 400K). Only when the
  content differs from the existing snapshot.
- When a new instance's log says `Failed to load configuration`, the
  watchdog kills it and starts the snapshot instead
  (`quickshell -p ~/.local/state/dots/quickshell-good -n`, same env as
  sway's exec_always), then shows
  `swaynag -t warning -m "quickshell config failed to load; running the last good one. qs log: <path>"`.
- While the fallback is running, the watchdog doesn't touch it until the
  real config loads again: `dots-reload quickshell` (after a fix) kills
  whatever runs and sway's exec_always starts the real config, which is
  checked again the same way.
- No snapshot yet (fresh machine): nothing to fall back to. The swaynag
  message says so and points at `dots-rescue`.

### 2. Lock: dots-lock with a swaylock fallback

- New `scripts/.local/bin/dots-lock`, the only thing that locks:
  `$mod+Escape`, swayidle (timeout and before-sleep), the command
  center's `:lock` action, and the watchdog's re-lock.
- It calls `qs ipc call lock lock`, then waits up to 2s for
  `quickshell-locked` to read `1`. If it doesn't, it runs `swaylock -f`
  (forks once locked, so `swayidle -w` before-sleep still waits for the
  lock) with the theme's black from `~/.rice` as the background.
- Already locked (`quickshell-locked` is `1`): nothing to do.
- swaylock goes in `packages.txt` (same name on dnf/apt/pacman).

### 3. sway: safe-mode retry (sway-session)

- `sway-session` moves into the repo (`sway/sway-session` plus
  `sway/sway.desktop`, not stowed) and `install.sh` installs both with
  sudo when they differ, like `/etc/pam.d/quickshell-lock`.
- It runs sway without `exec`. If sway exits non-zero within 10 seconds
  of starting, it runs sway once more with the distro's stock config
  (`-c /etc/sway/config`, which has its own bar and a terminal on
  `$mod+Return`), logging to `sway.log` that it fell back. A second
  failure returns to GDM, where GNOME is still available.
- `dots-reload` runs `sway --unsupported-gpu -C` before `swaymsg reload`
  and refuses the reload (keeping the running config) if it fails,
  printing the errors. `--doctor` runs the same check.

### 4. Hung session: dots-rescue

- New `scripts/.local/bin/dots-rescue` for a TTY (Ctrl+Alt+F3) or ssh.
  Finds the running sway's IPC socket itself (`/run/user/$UID/sway-ipc.*`),
  since a TTY has no `SWAYSOCK`.
- Subcommands, usage printed when run without one:
  - `quickshell`: SIGKILL quickshell; the watchdog brings it back.
  - `quickshell-good`: run the last-good snapshot now.
  - `quickshell-revert`: `git stash push -- quickshell/` in ~/.dots (so
    uncommitted work is kept, recoverable with `git stash pop`, rather
    than discarded), then restart quickshell.
  - `sway-reload`: `swaymsg reload` through the found socket.
  - `sway-exit`: end the sway session (back to GDM).
  - `unlock`: if locked with no working prompt, start swaylock so there
    is one.
- README gets a short "When things break" section listing these.

## Testing

- dots-lock: with quickshell running normally, it locks through
  quickshell (flag becomes 1). The fallback is exercised against a
  throwaway quickshell instance with a broken config (the scratch harness
  used for the lock screen), pointing dots-lock at it via a
  `DOTS_LOCK_QS_ARGS` override, and checking it decides to fall back. The
  real swaylock and real lock are run once by the user, who has the
  password.
- Watchdog fallback: run the watchdog's decision functions against the
  logs of a good and a broken throwaway instance; snapshot contents
  compared with the live config.
- sway-session: its retry logic is run with `sway` replaced by stub
  scripts (fails fast / runs long) via PATH, never the real compositor.
- dots-reload: a config with a syntax error is refused; the real one
  passes.
- shellcheck over all changed scripts, and `--doctor`.
