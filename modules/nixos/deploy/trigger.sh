# shellcheck shell=bash
# Start deploy-receiver.service, stream its log, and print what this host runs
# afterwards. Laptop agents run it over SSH. A polkit rule lets the fleet user
# start that one unit, and nothing else.
set -euo pipefail

since=$(date +%s)
journalctl --follow --since="@$since" --output=cat --unit=deploy-receiver.service &
follower=$!
status=0
systemctl start deploy-receiver.service || status=$?
sleep 1
kill "$follower" 2>/dev/null || true
wait "$follower" 2>/dev/null || true

if [[ -s $DEPLOY_STATE_FILE ]]; then
  read -r tag commit <"$DEPLOY_STATE_FILE"
  echo "$DEPLOY_HOST runs $tag $commit"
fi
exit "$status"
