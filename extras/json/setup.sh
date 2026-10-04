#!/usr/bin/env bash
# The json extra: jq, which nvim also formats JSON with (␣cf).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

pkg_install jq -- jq -- jq
