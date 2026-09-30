#!/usr/bin/env bash
# The backup extra: restic, snapshotting ~ every day through backup.timer
# (enabled by extras.sh once it's linked in). Where to and with what
# password lives in ~/.config/backup/env, per machine and never in the
# repo; this writes a template the first time, plus a random repository
# password if there isn't one yet.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

pkg_install restic -- restic -- restic

conf="$HOME/.config/backup"
mkdir -p "$conf"

if [ ! -f "$conf/password" ]; then
    echo "==> generating a repository password in $conf/password"
    (umask 077 && head -c 32 /dev/urandom | base64 >"$conf/password")
    echo "note: keep a copy of it somewhere else (a password manager) — the backup can't be read without it"
fi

if [ ! -f "$conf/env" ]; then
    echo "==> writing $conf/env"
    (umask 077 && cat >"$conf/env" <<'ENV'
# Read by ~/.local/bin/backup (the backup extra). Per machine, not in git.

# Where snapshots go: a local disk (/run/media/$USER/disk/restic), an ssh
# host (sftp:homeserver:/srv/backup/laptop), or any restic backend
# (s3:, b2:, rest:, rclone:). Create it once with `backup init`.
RESTIC_REPOSITORY=

RESTIC_PASSWORD_FILE=$HOME/.config/backup/password

# What gets backed up (a bash array); ~/.config/backup/excludes trims it.
BACKUP_PATHS=("$HOME")

# How many snapshots `backup` keeps after each run.
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=12
ENV
)
fi

if ! grep -q '^RESTIC_REPOSITORY=.' "$conf/env"; then
    echo "note: set RESTIC_REPOSITORY in $conf/env, then run 'backup init' once"
fi
