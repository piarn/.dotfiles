#!/usr/bin/env bash
# Installs what the mullvad extra needs, run by extras.sh before stowing:
# the Mullvad VPN app (its daemon + the `mullvad` CLI the quickshell widget
# drives) from Mullvad's own repository, since neither dnf nor apt ship it.
# A no-op once `mullvad` is on PATH, so safe to re-run.
set -euo pipefail

if ! command -v mullvad >/dev/null 2>&1; then
    echo "==> installing mullvad-vpn from repository.mullvad.net"
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf config-manager addrepo --overwrite \
            --from-repofile=https://repository.mullvad.net/rpm/stable/mullvad.repo
        sudo dnf install -y mullvad-vpn
    elif command -v apt >/dev/null 2>&1; then
        sudo curl -fsSLo /usr/share/keyrings/mullvad-keyring.asc \
            https://repository.mullvad.net/deb/mullvad-keyring.asc
        echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=$(dpkg --print-architecture)] https://repository.mullvad.net/deb/stable stable main" \
            | sudo tee /etc/apt/sources.list.d/mullvad.list >/dev/null
        sudo apt update && sudo apt install -y mullvad-vpn
    else
        echo "error: no supported package manager (apt/dnf); install Mullvad from https://mullvad.net/download" >&2
        exit 1
    fi
fi

# The package enables its daemon, but not on every distro/version.
if ! systemctl is-active --quiet mullvad-daemon; then
    sudo systemctl enable --now mullvad-daemon
fi

if ! mullvad account get >/dev/null 2>&1; then
    echo "note: not logged in yet — run 'mullvad account login <number>'"
fi
