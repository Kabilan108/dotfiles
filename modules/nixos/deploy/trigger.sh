# shellcheck shell=bash
# Start a deploy through the deploy-trigger socket, follow the receiver's log,
# and print what this host deployed and runs. Exits 0 only if that receiver run
# succeeded. Only members of the deploy-trigger group may connect. The socket
# only queues the receiver; this side follows it without privileges, through
# systemctl show, the journal, and the status the receiver records in
# DEPLOY_LAST_RUN (systemd forgets a finished run's result when it unloads the
# unit).
set -euo pipefail

unit=deploy-receiver.service

show() {
  systemctl show --property="$1" --value "$unit"
}

before=$(show InvocationID)
reply=$(timeout 30 socat -u "UNIX-CONNECT:$DEPLOY_TRIGGER_SOCKET" - || true)
if [[ $reply != "deploy-trigger: started" ]]; then
  echo "deploy-trigger: ${reply:-no reply from $DEPLOY_TRIGGER_SOCKET}" >&2
  exit 1
fi

# The start either joined a run already going or queued a new one.
id=""
for _ in $(seq 120); do
  current=$(show InvocationID)
  if [[ $(show ActiveState) == activating || $current != "$before" ]]; then
    id=$current
    break
  fi
  sleep 1
done
if [[ -z $id ]]; then
  echo "deploy-trigger: the receiver didn't start within two minutes" >&2
  exit 1
fi

journalctl --follow --lines=all --output=cat "_SYSTEMD_INVOCATION_ID=$id" &
follower=$!
while [[ $(show InvocationID) == "$id" ]]; do
  case $(show ActiveState) in
  activating | deactivating) sleep 1 ;;
  *) break ;;
  esac
done
sleep 1
kill "$follower" 2>/dev/null || true
wait "$follower" 2>/dev/null || true

status=""
if [[ -s $DEPLOY_LAST_RUN ]]; then
  read -r run status <"$DEPLOY_LAST_RUN"
  if [[ $run != "$id" ]]; then
    status=""
  fi
fi
if [[ -s $DEPLOY_STATE_FILE ]]; then
  read -r tag commit <"$DEPLOY_STATE_FILE"
  echo "$DEPLOY_HOST deployed $tag $commit"
fi
if running=$("$DEPLOY_NIXOS_VERSION" --configuration-revision 2>/dev/null); then
  echo "$DEPLOY_HOST runs $running"
fi
if [[ $status != 0 ]]; then
  echo "deploy-trigger: the receiver run failed (exit ${status:-unknown})" >&2
  exit 1
fi
