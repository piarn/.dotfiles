#!/usr/bin/env bash
# Installs what the protonvpn extra needs, run by extras.sh before stowing:
# Proton's open-source CLI (proton-vpn-cli, the `protonvpn` command the
# network popup drives) from repo.protonvpn.com — just the CLI, not the
# GTK app, which can't run alongside it anyway. On Arch it's a community
# AUR package instead (Proton doesn't run an Arch repo the way it does
# for apt/dnf). A no-op once installed.
set -euo pipefail
EXTRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Proton's repo packages are versioned; bump if these ever 404.
RPM_RELEASE=1.0.4-1
DEB_RELEASE=1.0.8

if ! command -v protonvpn >/dev/null 2>&1; then
    echo "==> installing proton-vpn-cli from repo.protonvpn.com"
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    if command -v dnf >/dev/null 2>&1; then
        curl -fsSL -o "$tmp/release.rpm" \
            "https://repo.protonvpn.com/fedora-$(rpm -E %fedora)-stable/protonvpn-stable-release/protonvpn-stable-release-${RPM_RELEASE}.noarch.rpm"
        rpm -q protonvpn-stable-release >/dev/null 2>&1 || sudo dnf install -y "$tmp/release.rpm"
        sudo dnf install -y proton-vpn-cli
    elif command -v apt >/dev/null 2>&1; then
        curl -fsSL -o "$tmp/release.deb" \
            "https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_${DEB_RELEASE}_all.deb"
        dpkg -s protonvpn-stable-release >/dev/null 2>&1 || sudo dpkg -i "$tmp/release.deb"
        sudo apt update && sudo apt install -y proton-vpn-cli
    elif command -v pacman >/dev/null 2>&1; then
        . "$EXTRA_DIR/../../.bootstrap/aur.sh"
        aur_install proton-vpn-cli
    else
        echo "error: no supported package manager (apt/dnf/pacman); see https://protonvpn.com/support/linux-cli" >&2
        exit 1
    fi
fi

if ! protonvpn config list >/dev/null 2>&1; then
    echo "note: sign in with [connect] in the network popup, or 'protonvpn signin <user>'"
fi
