#!/usr/bin/env bash
# The openvpn extra: NetworkManager's OpenVPN plugin, so .ovpn profiles can
# be imported and then show up in the network popup's vpn section like any
# other NM profile — no quickshell code of its own. Import one with
#   nmcli connection import type openvpn file <profile>.ovpn
# (or [settings] in the popup → nm-connection-editor).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

pkg_install NetworkManager-openvpn NetworkManager-openvpn-gnome \
    -- network-manager-openvpn network-manager-openvpn-gnome \
    -- networkmanager-openvpn
