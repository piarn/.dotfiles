#!/usr/bin/env bash
# Bootstraps this dotfiles repo onto a new machine via GNU Stow.
set -euo pipefail

DOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=(bash fish ghostty git nvim)

install_stow() {
    if command -v stow >/dev/null 2>&1; then
        return
    fi
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y stow
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y stow
    else
        echo "error: stow not found and no supported package manager (apt/dnf) detected" >&2
        exit 1
    fi
}

install_stow
cd "$DOTS_DIR"

for pkg in "${PACKAGES[@]}"; do
    echo "==> stowing $pkg"
    stow -v --no-folding --adopt -t "$HOME" "$pkg"
done

echo
echo "Done. Review 'git status' / 'git diff' in $DOTS_DIR — --adopt pulls any"
echo "pre-existing files at the target paths into the repo, which may have"
echo "overwritten tracked content with your local version. Discard with"
echo "'git checkout -- <file>' if the repo version should win instead."
