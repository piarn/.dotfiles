#!/usr/bin/env bash
# The nim extra: Nim and nimble, plus nimlangserver for editors. Debian
# and Arch package Nim; Fedora doesn't, so there it comes from choosenim
# (nim-lang.org's own installer) into ~/.nimble/bin — put that on PATH
# yourself. Update with `choosenim update stable`.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

if ! command -v nim >/dev/null 2>&1 && [ ! -x "$HOME/.nimble/bin/nim" ]; then
    if command -v dnf >/dev/null 2>&1; then
        tmp=$(mktemp)
        curl -sSfL https://nim-lang.org/choosenim/init.sh -o "$tmp"
        CHOOSENIM_NO_ANALYTICS=1 sh "$tmp" -y
        rm -f "$tmp"
    else
        pkg_install nim -- nim -- nim nimble
    fi
fi

export PATH="$HOME/.nimble/bin:$PATH"
command -v nimlangserver >/dev/null 2>&1 || nimble install -y nimlangserver
