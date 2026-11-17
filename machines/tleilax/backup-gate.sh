# shellcheck shell=bash
# backup-gate-executor IMAGE
# The ExecCondition of podman-executor-v2, so it runs after the old container
# has stopped. Executor starts when IMAGE is the one it last started with, or
# when none is recorded: a first start records IMAGE without a snapshot. Any
# other IMAGE waits for a snapshot tagged pre-update. If the snapshot fails,
# the condition fails: Executor stays stopped (Restart= doesn't retry a failed
# condition) and Tony gets an alert. IMAGE is recorded only after a snapshot
# succeeds, so an interrupted deploy or a reboot asks again.

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
