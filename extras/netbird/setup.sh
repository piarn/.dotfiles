#!/usr/bin/env bash
# Installs what the netbird extra needs, run by extras.sh before stowing:
# the NetBird client (daemon + the `netbird` CLI the network popup drives)
# from NetBird's own package repository. A no-op once `netbird` is on PATH.
set -euo pipefail

if ! command -v netbird >/dev/null 2>&1; then
    echo "==> installing netbird from pkgs.netbird.io"
    if command -v dnf >/dev/null 2>&1; then
        sudo tee /etc/yum.repos.d/netbird.repo >/dev/null <<'EOF'
[netbird]
name=netbird
baseurl=https://pkgs.netbird.io/yum/
enabled=1
gpgcheck=0
gpgkey=https://pkgs.netbird.io/yum/repodata/repomd.xml.key
repo_gpgcheck=1
EOF
        sudo dnf install -y netbird
    elif command -v apt >/dev/null 2>&1; then
        curl -fsSL https://pkgs.netbird.io/debian/public.key \
            | sudo gpg --dearmor --yes --output /usr/share/keyrings/netbird-archive-keyring.gpg
        echo 'deb [signed-by=/usr/share/keyrings/netbird-archive-keyring.gpg] https://pkgs.netbird.io/debian stable main' \
            | sudo tee /etc/apt/sources.list.d/netbird.list >/dev/null
        sudo apt update && sudo apt install -y netbird
    else
        echo "error: no supported package manager (apt/dnf); see https://docs.netbird.io/how-to/installation" >&2
        exit 1
    fi
fi

# The package doesn't register the daemon itself.
if ! systemctl is-active --quiet netbird; then
    sudo netbird service install 2>/dev/null || true
    sudo netbird service start
fi

if netbird status 2>&1 | grep -q NeedsLogin; then
    echo "note: log in with [connect] in the network popup (opens the browser),"
    echo "      or 'netbird up --management-url <url>' for a self-hosted server"
fi
