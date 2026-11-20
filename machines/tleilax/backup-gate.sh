# shellcheck shell=bash

version="$1"
state=/var/lib/backup/versions/executor

record() {
  local tmp
  mkdir -p "$(dirname "$state")"
  tmp="$(mktemp "$state.XXXXXX")"
  printf '%s\n' "$version" > "$tmp"
  sync "$tmp"
  mv -f "$tmp" "$state"
}

if [ ! -s "$state" ]; then
  echo "backup: no Executor image is recorded; recording $version without a snapshot"
  record
  exit 0
fi

recorded="$(cat "$state")"
if [ "$recorded" = "$version" ]; then
  exit 0
fi

echo "backup: Executor changes from $recorded to $version; taking a snapshot first"
if "$GATE_REPOSITORY_READY" \
  && restic backup --retry-lock 1h --tag executor --tag pre-update "$GATE_DATA_DIR"; then
  record
  echo "backup: snapshot taken; starting $version"
  exit 0
fi

echo "backup: the snapshot before the update failed, so Executor stays stopped. Fix it, then run: systemctl start podman-executor-v2" >&2
systemctl start --no-block backup-alert@preupdate-executor.service || true
exit 1
