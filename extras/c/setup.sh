#!/usr/bin/env bash
# The c extra: gcc and clang, make/cmake, gdb, clangd for editors.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

pkg_install gcc gcc-c++ clang clang-tools-extra make cmake gdb -- build-essential clang clangd cmake gdb -- gcc clang make cmake gdb
