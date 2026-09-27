#!/usr/bin/env bash
# Installs what the tailscale extra needs, run by extras.sh before stowing:
# Tailscale via its official installer (adds pkgs.tailscale.com for
# dnf/apt), the tailscaled service, and the current user as tailscale's
# operator so the network popup can run up/down/set without sudo.
set -euo pipefail

if ! command -v tailscale >/dev/null 2>&1; then
    echo "==> installing tailscale from pkgs.tailscale.com"
    curl -fsSL https://tailscale.com/install.sh | sh
fi

if ! systemctl is-active --quiet tailscaled; then
    sudo systemctl enable --now tailscaled
fi

if ! tailscale debug prefs 2>/dev/null | grep -q "\"OperatorUser\": \"$USER\""; then
    sudo tailscale set --operator="$USER"
fi

if tailscale status 2>&1 | grep -qi "logged out"; then
    echo "note: log in with [connect] in the network popup, or 'tailscale up'"
fi
