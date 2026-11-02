# backup-status JOB
# Runs after every attempt of a backup job (ExecStopPost). Records the result
# in $BACKUP_STATUS_DIR/<host>-<job>.json, keeping the last success time across
# failures. After a success it adds the repository size and the NAS's free
# space, alerts once when either crosses its threshold, and pushes the file to
# the status host if one is configured. Nothing here fails the run.

job="$1"
file="$BACKUP_STATUS_DIR/$BACKUP_HOST-$job.json"
now="$(date -Is)"
result="${SERVICE_RESULT:-unknown}"

previous='{}'
if [ -s "$file" ] && jq -e 'type == "object"' "$file" > /dev/null 2>&1; then
  previous="$(cat "$file")"
fi

repo_bytes=null
free_bytes=null
size_bytes=null
if [ "$result" = success ]; then
  repo_bytes="$(
    restic stats --retry-lock 10m --mode raw-data --json 2> /dev/null \
      | jq -r '.total_size // empty' || true
  )"
  [ -n "$repo_bytes" ] || repo_bytes=null
  if read -r size_bytes free_bytes < <(
    df --block-size=1 --output=size,avail "$BACKUP_REPOSITORY_DIR" 2> /dev/null | tail -n 1
  ); then
    :
  else
    size_bytes=null
    free_bytes=null
  fi
fi

over_size=false
low_free=false
if [ "$repo_bytes" != null ] && [ "$repo_bytes" -gt "$BACKUP_SIZE_ALERT_BYTES" ]; then
  over_size=true
fi
if [ "$size_bytes" != null ] && [ "$size_bytes" -gt 0 ] \
  && [ $((free_bytes * 100 / size_bytes)) -lt "$BACKUP_FREE_ALERT_PERCENT" ]; then
  low_free=true
fi

tmp="$(mktemp "$BACKUP_STATUS_DIR/.$BACKUP_HOST-$job.XXXXXX")"
jq -n \
  --argjson previous "$previous" \
  --arg host "$BACKUP_HOST" \
  --arg job "$job" \
  --arg now "$now" \
  --arg result "$result" \
  --arg exit_status "${EXIT_STATUS:-}" \
  --argjson repo_bytes "$repo_bytes" \
  --argjson free_bytes "$free_bytes" \
  --argjson size_bytes "$size_bytes" \
  --argjson over_size "$over_size" \
  --argjson low_free "$low_free" \
  '{
    host: $host,
    job: $job,
    last_attempt: $now,
    last_result: $result,
    last_exit_status: $exit_status,
    last_success: (if $result == "success" then $now else $previous.last_success end),
    repository_bytes: ($repo_bytes // $previous.repository_bytes),
    nas_free_bytes: ($free_bytes // $previous.nas_free_bytes),
    nas_size_bytes: ($size_bytes // $previous.nas_size_bytes),
    over_size: (if $result == "success" then $over_size else ($previous.over_size // false) end),
    low_free: (if $result == "success" then $low_free else ($previous.low_free // false) end)
  }' > "$tmp"
chmod 0644 "$tmp"
mv -f "$tmp" "$file"

was_over="$(jq -r '.over_size // false' <<< "$previous")"
was_low="$(jq -r '.low_free // false' <<< "$previous")"
if { [ "$over_size" = true ] && [ "$was_over" != true ]; } \
  || { [ "$low_free" = true ] && [ "$was_low" != true ]; }; then
  systemctl start --no-block "backup-alert@threshold-$job.service" || true
fi

if [ -n "$BACKUP_PUSH_TARGET" ]; then
  ssh -i "$BACKUP_PUSH_KEY" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o ConnectTimeout=15 \
    "$BACKUP_PUSH_TARGET" < "$file" \
    || echo "backup-status: could not push the status to $BACKUP_PUSH_TARGET" >&2
fi
