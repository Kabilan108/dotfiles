# shellcheck shell=bash

job="$1"
unit="restic-backups-$job.service"
counter="$BACKUP_RETRY_DIR/$job"

if [ "${SERVICE_RESULT:-}" = success ]; then
  rm -f -- "$counter"
  systemctl stop "backup-retry-$job.timer" 2> /dev/null || true
  exit 0
fi

failures=0
if [ -f "$counter" ]; then
  failures="$(cat "$counter")"
  case "$failures" in
    "" | *[!0-9]*) failures=0 ;;
  esac
fi
failures=$((failures + 1))

if [ "$failures" -le "$BACKUP_RETRY_ATTEMPTS" ]; then
  printf '%s\n' "$failures" > "$counter"
  echo "backup: attempt $failures failed; retrying in ${BACKUP_RETRY_DELAY_SEC}s"
  systemctl stop "backup-retry-$job.timer" 2> /dev/null || true
  systemd-run --quiet \
    --unit="backup-retry-$job" \
    --on-active="${BACKUP_RETRY_DELAY_SEC}s" \
    --timer-property=AccuracySec=1s \
    systemctl start --no-block "$unit"
else
  rm -f -- "$counter"
  echo "backup: giving up after $failures attempts"
  systemctl start --no-block "backup-alert@restic-backups-$job.service"
fi
