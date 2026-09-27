#!/usr/bin/env bash
# The openconnect extra: NetworkManager's openconnect plugin, for Cisco
# AnyConnect, Palo Alto GlobalProtect, Fortinet, Juniper/Pulse and Array
# SSL VPNs. Create a profile with [settings] in the network popup
# (nm-connection-editor → + → VPN); it then shows up in the popup's vpn
# section like any other NM profile — no quickshell code of its own.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

pkg_install NetworkManager-openconnect NetworkManager-openconnect-gnome \
    -- network-manager-openconnect network-manager-openconnect-gnome
