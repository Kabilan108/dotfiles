# shellcheck shell=bash
# backup-stale-check
# Runs daily as the alert user on the host that receives other hosts' status
# files. An offline laptop can't alert for itself, so this alerts once when a
# received job hasn't succeeded within BACKUP_STALE_AFTER_SEC, or when a host
# has sent no status at all. A failed alert leaves no mark and is retried on
# the next run; a fresh success clears the mark.

marks="$BACKUP_RECEIVED_DIR/.stale-alerted"
mkdir -p "$marks"
now="$(date +%s)"

# alert_once MARK VALUE ALERT-ARGS...: alerts unless MARK already holds VALUE.
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

for host in $BACKUP_STALE_HOSTS; do
  found=false
  for file in "$BACKUP_RECEIVED_DIR/$host"-*.json; do
    [ -e "$file" ] || continue
    found=true
    job="$(basename "$file" .json)"
    job="${job#"$host"-}"
    last="$(jq -r '.last_success // empty' "$file" 2> /dev/null || true)"
    if [ -n "$last" ] && last_sec="$(date -d "$last" +%s 2> /dev/null)" \
      && [ $((now - last_sec)) -le "$BACKUP_STALE_AFTER_SEC" ]; then
      rm -f -- "$marks/$host-$job"
      continue
    fi
    alert_once "$marks/$host-$job" "${last:-never}" stale "$host" "$job"
  done
  if [ "$found" = true ]; then
    rm -f -- "$marks/$host"
  else
    alert_once "$marks/$host" none stale "$host"
  fi
done
