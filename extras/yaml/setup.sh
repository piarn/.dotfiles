#!/usr/bin/env bash
# The yaml extra: yq (mikefarah's) and yamllint; nvim formats YAML with yq
# (␣cf) and lints with yamllint. Debian/Ubuntu's `yq` is a different tool
# (the Python jq wrapper), so there only yamllint is installed.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

pkg_install yq yamllint -- yamllint -- go-yq yamllint
