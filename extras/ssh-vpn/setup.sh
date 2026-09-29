#!/usr/bin/env bash
# The ssh-vpn extra: NetworkManager's SSH plugin — a tun/tap VPN over a
# plain SSH login, no VPN server software needed on the other end. Create a
# profile with [settings] in the network popup; it then shows up in the
# popup's vpn section like any other NM profile — no quickshell code of its
# own.
set -euo pipefail
EXTRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$EXTRA_DIR/../lib.sh"

# No official Arch package (unlike openconnect/openvpn/vpnc/wireguard) —
# only an AUR one, so pacman never installs anything here; pkg_install
# falls through to the AUR branch below on Arch.
pkg_install NetworkManager-ssh NetworkManager-ssh-gnome \
    -- network-manager-ssh network-manager-ssh-gnome

if command -v pacman >/dev/null 2>&1 && ! pacman -Qq networkmanager-ssh-git >/dev/null 2>&1; then
    . "$EXTRA_DIR/../../.bootstrap/aur.sh"
    aur_install networkmanager-ssh-git
fi
