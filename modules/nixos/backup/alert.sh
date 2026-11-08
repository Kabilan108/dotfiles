# backup-alert INSTANCE
# Runs as the alert user (backup-alert@.service), never as root.
#   restic-backups-<job>  the job failed after all its retries
#   threshold-<job>       the job's status crossed a size or free-space threshold

instance="$1"

case "$instance" in
  restic-backups-*)
    job="${instance#restic-backups-}"
    title="Backup failed on $BACKUP_HOST"
    body="The $job backup job failed after its retries. Check \`journalctl -u $instance\` on $BACKUP_HOST."
    ;;
  threshold-*)
    job="${instance#threshold-}"
    file="$BACKUP_STATUS_DIR/$BACKUP_HOST-$job.json"
    title="Backup storage check on $BACKUP_HOST"
    body="$(jq -r '
      def gib: if . == null then "unknown" else ((. / 1073741824 * 10 | floor) / 10 | tostring) + " GiB" end;
      "The \(.job) repository is \(.repository_bytes | gib); the NAS has \(.nas_free_bytes | gib) free of \(.nas_size_bytes | gib)."
      + (if .over_size then " The repository passed its size threshold: time to consider pruning." else "" end)
      + (if .low_free then " NAS free space is below its threshold." else "" end)
    ' "$file")"
    ;;
  *)
    echo "backup-alert: unknown instance $instance" >&2
    exit 1
    ;;
esac

payload="$(jq -cn --arg title "$title" --arg body "$body" --arg project "$BACKUP_ALERT_PROJECT" \
  '{title: $title, body: $body, project: $project}')"

if [ -n "$BACKUP_ALERT_OUTPUT" ]; then
  printf '%s\n' "$payload" >> "$BACKUP_ALERT_OUTPUT"
  exit 0
fi

printf '%s' "$payload" | curl \
  --config "$BACKUP_ALERT_CURL_CONFIG" \
  --silent \
  --show-error \
  --fail \
  --output /dev/null \
  --header "Content-Type: application/json" \
  --header "Idempotency-Key: backup:$BACKUP_HOST:$instance:$(date +%Y-%m-%dT%H)" \
  --data-binary @-
