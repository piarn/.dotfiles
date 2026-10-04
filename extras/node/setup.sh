#!/usr/bin/env bash
# The node extra: Node.js and npm from the distro.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# Fedora ships versioned packages (nodejs22), so rpm -q nodejs misses an
# install that works fine; trust the binaries.
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    pkg_install nodejs nodejs-npm -- nodejs npm -- nodejs npm
fi
