#!/usr/bin/env bash
# The go extra: the distro's Go toolchain, plus gopls and delve (dlv) via
# `go install` into $(go env GOPATH)/bin — put that on PATH yourself.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

pkg_install golang -- golang-go -- go

for tool in gopls:golang.org/x/tools/gopls dlv:github.com/go-delve/delve/cmd/dlv; do
    bin=${tool%%:*}
    [ -x "$(go env GOPATH)/bin/$bin" ] || command -v "$bin" >/dev/null 2>&1 \
        || go install "${tool#*:}@latest"
done
