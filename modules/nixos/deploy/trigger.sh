# shellcheck shell=bash
# Start a deploy through the deploy-trigger socket, follow the receiver's log,
# and print what this host deployed and runs. Exits 0 only if the receiver run
# serving this request succeeded. Only members of the deploy-trigger group may
# connect.
#
# The broker replies with the systemd job it queued or joined. The run that job
# starts records itself in DEPLOY_RUNS (run-record.sh), so this finds its
# outcome however soon the run ends; the unit's own state is gone once systemd
# unloads it.
set -euo pipefail

reply=$(timeout 30 socat -u "UNIX-CONNECT:$DEPLOY_TRIGGER_SOCKET" - || true)
if [[ ! $reply =~ ^deploy-trigger:\ queued\ job\ ([0-9]+)$ ]]; then
  echo "deploy-trigger: ${reply:-no reply from $DEPLOY_TRIGGER_SOCKET}" >&2
  exit 1
fi
job=${BASH_REMATCH[1]}

# Prints "<invocation id> <state>" from the job's latest record, if any.
run_record() {
  awk -v job="$job" '$1 == job { invocation = $2; state = $3 }
    END { if (invocation != "") print invocation, state }' "$DEPLOY_RUNS" 2>/dev/null || true
}

job_pending() {
  systemctl list-jobs --no-legend | awk -v job="$job" '$1 == job { found = 1 } END { exit !found }'
}

invocation="" state="" follower=""
while :; do
  read -r invocation state <<<"$(run_record)" || true
  if [[ -n $invocation && -z $follower ]]; then
    journalctl --follow --lines=all --output=cat "_SYSTEMD_INVOCATION_ID=$invocation" &
    follower=$!
  fi
  if [[ $state == exit:* ]]; then
    break
  fi
  if ! job_pending; then
    # The exit record is written before the job ends, so one last look.
    read -r invocation state <<<"$(run_record)" || true
    break
  fi
  sleep 1
done
if [[ -n $follower ]]; then
  sleep 1
  kill "$follower" 2>/dev/null || true
  wait "$follower" 2>/dev/null || true
elif [[ -n $invocation ]]; then
  journalctl --lines=all --output=cat "_SYSTEMD_INVOCATION_ID=$invocation" || true
fi

if [[ -s $DEPLOY_STATE_FILE ]]; then
  read -r tag commit <"$DEPLOY_STATE_FILE"
  echo "$DEPLOY_HOST deployed $tag $commit"
fi
if running=$("$DEPLOY_NIXOS_VERSION" --configuration-revision 2>/dev/null); then
  echo "$DEPLOY_HOST runs $running"
fi
case $state in
exit:0) ;;
exit:*)
  echo "deploy-trigger: the receiver run for job $job failed (exit ${state#exit:})" >&2
  exit 1
  ;;
*)
  echo "deploy-trigger: job $job ended without the receiver recording a result" >&2
  exit 1
  ;;
esac
