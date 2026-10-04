#!/usr/bin/env bash
# The lua extra: Lua 5.4, LuaJIT and luarocks.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

pkg_install lua luajit luarocks -- lua5.4 luajit luarocks -- lua luajit luarocks
