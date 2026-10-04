#!/usr/bin/env bash
# The python extra: Python 3 with pip, venv and headers, pipx and uv. uv
# isn't in every distro's repos (e.g. Ubuntu), so it falls back to pipx.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

pkg_install python3 python3-pip python3-devel pipx -- python3 python3-pip python3-venv python3-dev pipx -- python python-pip python-pipx

if ! command -v uv >/dev/null 2>&1; then
    pkg_install uv -- uv -- uv 2>/dev/null || pipx install uv
fi
