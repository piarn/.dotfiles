# Island: one centered surface for the whole shell

## Goal

Replace the GNOME-shaped layout (full-width bar of three pills, popups in
the top-right corner, calendar under a centered clock, launcher in the
screen center) with one fixed-width **island** centered at the top of each
monitor. Collapsed it's the status strip; it grows downward, at the same
width, into a tabbed panel holding everything the popups hold today. One
width, one place, one border.

Decided with the user:
- Direction: floating island (over a bottom terminal line or a side rail),
  status as terse text segments.
- Opening: the island itself grows (one surface), not cards under it and
  not per-segment drop-downs.
- Quick settings, calendar, notifications, network, the command center
  and clipboard history all become island tabs.
- Width: 600px, collapsed and grown, every monitor.
- Implementation: approach A (a growing island window plus an invisible
  spacer reserving the collapsed height), not restyled separate popups or
  a fullscreen masked overlay.

Out of scope: the lock screen (unchanged), the OSD (stays centered as
today; could move into the strip later), new features inside tabs.

## What it looks like

Collapsed (600px, centered, top):

```
 1 2 3 │            22:48            │ ☁15° az 78% ●
```

- left: workspaces as text, current one inverted (tmux window list style)
- center: clock
- right: weather, network label, battery %, and ● while notifications are
  unread; amber/red when something needs attention (today's ≡ colour rules)

Grown: the same 600px strip, extended downward by a tab row and the tab:

```
 system │ calendar │ notifications 3 │ network │ run │ clipboard
```

| tab | from today's | notes |
|---|---|---|
| system | QuickSettings (+ BatteryMenu section) | toggles, sliders, tray, battery details |
| calendar | CalendarMenu's calendar part | stacked layout at 600px |
| notifications | CalendarMenu's notification part | silence, clear all, list |
| network | NetworkMenu | wifi, bluetooth, VPN sections |
| run | CommandCenter (+ its sections) | search field at the top |
| clipboard | ClipboardMenu | |

Tall tabs scroll inside a cap of 70% of the screen height.

## Interaction

| trigger | opens |
|---|---|
| click clock | calendar |
| click status segments | system |
| click ● | notifications |
| `$mod+n` | system |
| `$mod+d`, `$mod+Space` | run |
| `$mod+Shift+Escape` | run with `:` |
| `$mod+v` | clipboard |

- Tab switching: `h`/`l` (or ←/→) where nothing is being typed,
  Ctrl+Tab / Ctrl+Shift+Tab anywhere (plain Tab already moves the run
  tab's result list), or clicking the tab row.
- Collapse: `Esc`, clicking outside, or the same trigger again.
- Keyboard focus follows today's rules (CardWindow's notes on sway
  1.9+): run and clipboard take the keyboard exclusively with a
  click-away catcher; the other tabs are on-demand and collapse when focus
  moves to another window.
- IPC names keep working and map to tabs: `popup toggle quicksettings|
  battery → system`, `calendar`, `notifications`, `network|bluetooth →
  network`, `commandcenter toggle|open <prefix> → run`, `clipboard toggle →
  clipboard`.
- Only one island is grown at a time: the one on the monitor that was
  clicked or is focused.

## Architecture

- `state/IslandState.qml` (singleton, replaces PopupState): `tab` (""
  when collapsed), `screen`, `open(tab, screen)`, `toggle(tab, screen)`,
  `close()`, `next()/prev()`. Name → tab routing (old popup names and IPC
  names) lives in `island/routes.js`, pure JS.
- `island/Island.qml` (per screen, via Variants in shell.qml): a
  CardWindow in a new `topCenter` placement, `exclusionMode: Ignore`,
  width 600, height = strip + (grown ? tab row + tab : 0).
  `needsKeyboard`/`clickAwayCloses` true on run/clipboard. Contains
  `island/IslandView.qml`, an Item with the strip, tab row and tab body —
  no window, so the same view renders in an ordinary window for previews.
- `island/Spacer.qml` (per screen): a transparent PanelWindow across the
  top reserving the collapsed strip's height as exclusive zone, taking no
  input, so windows sit below the collapsed island and never move when it
  grows (the grown island overlays them).
- `island/Strip.qml`: the collapsed row (from Bar.qml's workspace, clock,
  weather and status logic).
- Tabs `island/tabs/{System,Calendar,Notifications,Network,Run,Clipboard}Tab.qml`:
  today's popup bodies, moved out of their BarPopup/CardWindow wrappers.
  Their logic, state singletons and components stay as they are;
  `menu.openPopup(x)` calls become `IslandState.open(x)`.
- Toasts (`NotificationToasts.qml`): top-center, 600px, placed just under
  the collapsed strip.
- Removed once migrated: `Bar.qml`, `components/BarPopup.qml`,
  `components/BarWidget.qml`, `state/PopupState.qml`, and the six popup
  windows' wrappers. The IPC handlers in shell.qml / CommandCenter /
  ClipboardMenu move to one place that routes through `routes.js`.

## Error handling

- A broken island is a broken quickshell config: qs-watchdog's last-good
  fallback applies (the snapshot will be the pre-island config until the
  island loads once).
- Grown state never survives a restart (collapsed on start).
- A tab whose data isn't available (no battery, no tray items, no
  weather) hides that part, as today.

## Testing

- `routes.js` (name/IPC → tab, tab order for next/prev) under node,
  `tests/test-island-routes.sh`, same pattern as test-calendar.sh.
- Each task renders `IslandView` (collapsed and every tab) in a throwaway
  quickshell instance in an ordinary window and saves PNGs via
  grabToImage — the same harness used for the lock screen — so layout is
  checked without opening anything on the live bar; that instance stubs
  NotificationState so it can't take the notification D-Bus name.
- Live: quickshell log clean after `dots-reload quickshell`; the user
  checks focus behaviour (click-away, Esc, exclusive tabs), which can't
  be driven from a script without taking over the session.
- Existing suite (tests/run.sh) and shellcheck stay green.
