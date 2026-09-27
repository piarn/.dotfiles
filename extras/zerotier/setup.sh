#!/usr/bin/env bash
# Installs what the zerotier extra needs, run by extras.sh before stowing:
# ZeroTier One via its official installer (adds download.zerotier.com for
# dnf/apt), verified against ZeroTier's signing key first; the
# zerotier-one service; and a copy of its auth token in
# ~/.zeroTierOneAuthToken, which zerotier-cli reads when not run as root.
set -euo pipefail

if ! command -v zerotier-cli >/dev/null 2>&1; then
    echo "==> installing zerotier-one from download.zerotier.com"
    gnupg=$(mktemp -d)
    trap 'rm -rf "$gnupg"' EXIT
    curl -fsSL 'https://raw.githubusercontent.com/zerotier/ZeroTierOne/main/doc/contact%40zerotier.com.gpg' \
        | gpg --homedir "$gnupg" --import
    script=$(curl -fsSL https://install.zerotier.com/ | gpg --homedir "$gnupg")
    echo "$script" | sudo bash
fi

if ! systemctl is-active --quiet zerotier-one; then
    sudo systemctl enable --now zerotier-one
fi

token="$HOME/.zeroTierOneAuthToken"
if [ ! -s "$token" ]; then
    (umask 077 && sudo cat /var/lib/zerotier-one/authtoken.secret >"$token")
fi

echo "note: this node is $(zerotier-cli info | cut -d' ' -f3); join a network from the"
echo "      network popup's ZeroTier panel, then authorize the node on the network"
