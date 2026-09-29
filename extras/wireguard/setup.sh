#!/usr/bin/env bash
# The wireguard extra: wireguard-tools (wg, wg-quick). NetworkManager
# handles WireGuard natively, so imported configs show up in the network
# popup's vpn section like any other NM profile — no quickshell code of its
# own. Import one with
#   nmcli connection import type wireguard file <name>.conf
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

pkg_install wireguard-tools -- wireguard-tools -- wireguard-tools
