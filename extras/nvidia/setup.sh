#!/usr/bin/env bash
# The nvidia extra: what sway on the proprietary NVIDIA driver needs that
# the base dotfiles don't. Run by extras.sh; a no-op once it's all in place.
#
# sway >= 1.12. Fedora 44 ships sway 1.11 on wlroots 0.19, whose
# explicit-sync release path aborts sway, so .bootstrap/sway-session
# turns explicit sync off for it — and with NVIDIA's driver that makes
# regions of the screen flicker or show stale frames. Fedora's next
# release packages 1.12 against wlroots 0.20, which F44 already ships, so
# its dist-git branch rebuilds as-is here; a later Fedora update to 1.12+
# just replaces it. Only the sway subpackages already installed (sway,
# sway-config-upstream) get swapped. Sources come from Fedora's lookaside
# cache, checked against dist-git's `sources` hashes. Arch already ships
# 1.12; elsewhere this only says what's missing.
set -euo pipefail

SWAY_MIN_VERSION=1.12
SWAY_DISTGIT_BRANCH=f45

sway_version=$(sway --version 2>/dev/null | awk '{print $3}')
if [ -z "$sway_version" ] \
    || [ "$(printf '%s\n%s\n' "$SWAY_MIN_VERSION" "$sway_version" | sort -V | head -n1)" = "$SWAY_MIN_VERSION" ]; then
    exit 0
fi
if ! command -v dnf >/dev/null 2>&1; then
    echo "note: sway $sway_version < $SWAY_MIN_VERSION, so sway-session keeps explicit sync off (expect NVIDIA flicker); install sway $SWAY_MIN_VERSION+ from your distro" >&2
    exit 0
fi

echo "==> rebuilding Fedora's sway package ($SWAY_DISTGIT_BRANCH) to replace sway $sway_version (a few minutes)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone -q --depth 1 --branch "$SWAY_DISTGIT_BRANCH" https://src.fedoraproject.org/rpms/sway.git "$tmp/sway"
(
    cd "$tmp/sway"
    sudo dnf install -y rpm-build
    sudo dnf builddep -y sway.spec
    while read -r _ file _ hash; do
        file=${file#(}; file=${file%)}
        curl -fsSL -o "$file" "https://src.fedoraproject.org/repo/pkgs/rpms/sway/$file/sha512/$hash/$file"
    done <sources
    sha512sum -c sources
    rpmbuild -bb --define "_topdir $tmp/rpmbuild" --define "_sourcedir $PWD" sway.spec
)
pkgs=()
for rpm in "$tmp"/rpmbuild/RPMS/*/*.rpm; do
    rpm -q "$(rpm -qp --qf '%{NAME}' "$rpm")" >/dev/null 2>&1 && pkgs+=("$rpm")
done
sudo dnf install -y "${pkgs[@]}"
echo "==> sway $(sway --version | awk '{print $3}') installed; log out and back in to start it"
