#!/usr/bin/env bash
# Runs every tests/test-*.sh; exits non-zero if any failed.
cd "$(dirname "$0")" || exit 1
status=0
for t in test-*.sh; do
    echo "$t"
    bash "$t" || status=1
done
exit "$status"
