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

`install.sh` installs `stow` (apt/dnf) if missing, then symlinks each
package into `$HOME`. It runs with `--adopt`, so any real file already
sitting at a target path (e.g. an existing `~/.bashrc`) is moved into the
repo first, then symlinked back — check `git diff` afterward and revert
with `git checkout -- <file>` if the repo version should have won.

## Adding a package

```
mkdir -p newpkg/.config/newtool
# add files under newpkg/... mirroring their $HOME path
```

Then add `newpkg` to the `PACKAGES` array in `install.sh`.
