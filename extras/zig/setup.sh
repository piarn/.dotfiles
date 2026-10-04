#!/usr/bin/env bash
# The zig extra: Zig from the distro. Packaged on Fedora and Arch; on
# Debian/Ubuntu it depends on the release, so apt may not find it.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

pkg_install zig -- zig -- zig
