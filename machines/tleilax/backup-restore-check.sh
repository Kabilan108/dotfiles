# shellcheck shell=bash

snapshot="${1:-latest}"
name="executor-v2-restore-check"
work=""

fail() {
  echo "Restore check FAILED: $*" >&2
  exit 1
}

cleanup() {
  podman rm --force --ignore --time 10 "$name" > /dev/null 2>&1 || true
  if [ -n "$work" ]; then
    rm -rf --one-file-system -- "$work"
  fi
}

if [ "$(id -u)" != 0 ]; then
  echo "Run it as root: sudo backup-restore-check-executor" >&2
  exit 1
fi

trap cleanup EXIT
podman rm --force --ignore "$name" > /dev/null 2>&1 || true

"$CHECK_REPOSITORY_READY"
echo "Snapshot:"
if [ "$snapshot" = latest ]; then
  restic snapshots --no-lock --tag "$CHECK_TAG" --latest 1
else
  restic snapshots --no-lock "$snapshot"
fi

work="$(mktemp -d /var/lib/backup-restore-check.XXXXXX)"
echo "Restoring into $work"
restic restore --no-lock "$snapshot" --tag "$CHECK_TAG" --target "$work"
data="$work$CHECK_DATA_DIR"
[ -d "$data" ] || fail "the snapshot holds no $CHECK_DATA_DIR"
chown -R "$CHECK_OWNER" "$data"

telemetry="$work/motel-data"
install -d -m 0700 -o "${CHECK_OWNER%%:*}" -g "${CHECK_OWNER##*:}" "$telemetry"

echo "Starting $CHECK_IMAGE as $name, with no network"
podman run --detach --name "$name" --network=none --pull=never --init \
  --user "$CHECK_OWNER" --env-file "$CHECK_ENV_FILE" --env-file "$CHECK_KEYS_FILE" \
  --volume "$data:/app/data" --volume "$telemetry:/app/motel-data" \
  "$CHECK_IMAGE" > /dev/null

running() {
  [ "$(podman inspect --format '{{.State.Running}}' "$name" 2> /dev/null)" = true ]
}

show_logs() {
  echo "Container logs:" >&2
  podman logs "$name" >&2 2>&1 || true
}

health=""
healthy=false
for _ in $(seq 1 90); do
  if ! running; then
    show_logs
    fail "the container stopped before it reported healthy"
  fi
  if health="$(podman exec "$name" executor-host health 2>&1)"; then
    healthy=true
    break
  fi
  sleep 2
done
if [ "$healthy" != true ]; then
  show_logs
  fail "executor-host health never succeeded; its last answer: $health"
fi
echo "executor-host health: $health"

logs="$(podman logs "$name" 2>&1)"
if bad="$(grep -Ei 'error|fail|fatal|panic|refus' <<< "$logs" | grep -Ei 'migrat|encrypt|decrypt|key')"; then
  show_logs
  fail "the logs show a migration or key error: $bad"
fi
echo "The container stayed up and its logs show no migration or key error."

repos=0
broken=0
while IFS= read -r -d '' head; do
  dir="$(dirname "$head")"
  if [ ! -d "$dir/objects" ] || [ ! -d "$dir/refs" ]; then
    continue
  fi
  repos=$((repos + 1))
  if git -c safe.directory='*' --git-dir="$dir" fsck --no-progress --no-dangling > "$work/fsck.log" 2>&1; then
    echo "git fsck ok: ${dir#"$data"/}"
  else
    echo "git fsck FAILED: ${dir#"$data"/}" >&2
    cat "$work/fsck.log" >&2
    broken=$((broken + 1))
  fi
done < <(find "$data" -name HEAD -type f -print0)

if [ "$repos" = 0 ]; then
  echo "No git repositories found under $CHECK_DATA_DIR."
fi
if [ "$broken" != 0 ]; then
  fail "git fsck failed for $broken of $repos repositories"
fi
echo "Restore check passed: $repos git repositories checked."
