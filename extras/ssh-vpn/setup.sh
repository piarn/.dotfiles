#!/usr/bin/env bash
# The ssh-vpn extra: NetworkManager's SSH plugin — a tun/tap VPN over a
# plain SSH login, no VPN server software needed on the other end. Create a
# profile with [settings] in the network popup; it then shows up in the
# popup's vpn section like any other NM profile — no quickshell code of its
# own.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

pkg_install NetworkManager-ssh NetworkManager-ssh-gnome \
    -- network-manager-ssh network-manager-ssh-gnome
