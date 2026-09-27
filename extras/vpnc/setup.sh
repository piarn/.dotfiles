#!/usr/bin/env bash
# The vpnc extra: NetworkManager's vpnc plugin, for Cisco IPsec (EasyVPN)
# concentrators. Create or import (.pcf) a profile with [settings] in the
# network popup; it then shows up in the popup's vpn section like any other
# NM profile — no quickshell code of its own.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

pkg_install NetworkManager-vpnc NetworkManager-vpnc-gnome \
    -- network-manager-vpnc network-manager-vpnc-gnome
