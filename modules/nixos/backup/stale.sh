# shellcheck shell=bash

marks="$BACKUP_STALE_MARKS"
mkdir -p "$marks"
now="$(date +%s)"

alert_once() {
  local mark="$1" value="$2"
  shift 2
  if [ -e "$mark" ] && [ "$(cat "$mark")" = "$value" ]; then
    return 0
  fi
  if "$BACKUP_ALERT" "$@"; then
    printf '%s' "$value" > "$mark"
  else
    echo "backup-stale-check: alert for $* failed" >&2
  fi
}

check_job() {
  local host="$1" job="$2" file="$3" last="" last_sec
  if [ -e "$file" ]; then
    last="$(jq -r '.last_success // empty' "$file" 2> /dev/null || true)"
  fi
  if [ -n "$last" ] && last_sec="$(date -d "$last" +%s 2> /dev/null)" \
    && [ $((now - last_sec)) -le "$BACKUP_STALE_AFTER_SEC" ]; then
    rm -f -- "$marks/$host-$job"
    return 0
  fi
  alert_once "$marks/$host-$job" "${last:-never}" stale "$host" "$job"
}

for host in $BACKUP_STALE_HOSTS; do
  found=false
  for file in "$BACKUP_RECEIVED_DIR/$host"-*.json; do
    [ -e "$file" ] || continue
    found=true
    job="$(basename "$file" .json)"
    check_job "$host" "${job#"$host"-}" "$file"
  done
  if [ "$found" = true ]; then
    rm -f -- "$marks/$host"
  else
    alert_once "$marks/$host" none stale "$host"
  fi
done

for job in $BACKUP_STALE_OWN_JOBS; do
  check_job "$BACKUP_HOST" "$job" "$BACKUP_STATUS_DIR/$BACKUP_HOST-$job.json"
done
