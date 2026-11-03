# backup-status-receive HOST
# The forced command for HOST's status key: reads one status JSON object from
# stdin and stores it as ~/.local/state/backup-status/HOST-JOB.json.

host="$1"
case "$host" in
  "" | *[!a-z0-9-]*)
    echo "backup-status-receive: bad host name" >&2
    exit 1
    ;;
esac

dir="$HOME/.local/state/backup-status"
mkdir -p "$dir"
tmp="$(mktemp "$dir/.$host.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

head -c 65537 > "$tmp"
if [ "$(stat -c %s "$tmp")" -gt 65536 ]; then
  echo "backup-status-receive: status too large" >&2
  exit 1
fi
if ! job="$(jq -er --arg host "$host" '
  select(type == "object" and .host == $host and (.job | type == "string" and test("^[a-z0-9-]+$")))
  | .job' "$tmp")"; then
  echo "backup-status-receive: not a status object for $host" >&2
  exit 1
fi
chmod 0644 "$tmp"
mv -f "$tmp" "$dir/$host-$job.json"
trap - EXIT
