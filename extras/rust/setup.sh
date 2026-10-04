#!/usr/bin/env bash
# The rust extra: rustc, cargo and rust-analyzer from the distro. Use
# rustup yourself if you want to switch toolchains.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

pkg_install rust cargo rust-analyzer -- rustc cargo rust-analyzer -- rust rust-analyzer
