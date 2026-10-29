# shellcheck shell=bash
# Runs as root once per connection to the deploy-trigger socket. Starts
# deploy-receiver.service with a fixed job mode, streams its log to the caller,
# then reports what the host deployed and runs, and the receiver's exit status
# as the last line. It reads nothing from the caller, so a caller can only say
# "now".
set -euo pipefail

since=$(date +%s)
journalctl --follow --since="@$since" --output=cat --unit=deploy-receiver.service &
follower=$!
status=0
systemctl start --job-mode=replace deploy-receiver.service || status=$?
sleep 1
kill "$follower" 2>/dev/null || true
wait "$follower" 2>/dev/null || true

if [[ -s $DEPLOY_STATE_FILE ]]; then
  read -r tag commit <"$DEPLOY_STATE_FILE"
  echo "$DEPLOY_HOST deployed $tag $commit"
fi
if running=$("$DEPLOY_NIXOS_VERSION" --configuration-revision 2>/dev/null); then
  echo "$DEPLOY_HOST runs $running"
fi
echo "deploy-trigger-status $status"
