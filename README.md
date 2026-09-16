# .dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level
directory (`bash`, `fish`, `ghostty`, ...) is a stow package whose contents
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
the resulting plugin files are committed under `fish/.config/fish`).

## .rice

This repo owns *configs*; [`~/.rice`](https://github.com/piarn/.rice) owns
the *styling* layer several of them include or symlink from — sway's
colors/gaps/screen-layout, tmux/nvim/fish accents, and the
yazi/lazygit/lazydocker/swaylock/firefox theme files. `install.sh` clones
it to `~/.rice` if it isn't already there, renders the current theme
(`~/.rice/bin/apply-theme`), and — if sway is already running — applies
whichever screen layout matches what's connected
(`~/.rice/bin/apply-layout --auto`). Both are safe to re-run any time; see
`~/.rice/README.md` for how theming and screen layouts actually work.

## Adding a package

```
mkdir -p newpkg/.config/newtool
# add files under newpkg/... mirroring their $HOME path
```

Then add `newpkg` to the `PACKAGES` array in `install.sh`.
