# shellcheck shell=bash
set -euo pipefail

job=$(systemctl show --property=Job --value deploy-receiver.service)
if [[ ! $job =~ ^[0-9]+$ ]]; then
  job=none
fi

record() {
  {
    tail -n 99 "$DEPLOY_RUNS" 2>/dev/null || true
    echo "$job ${INVOCATION_ID:-none} $1"
  } >"$DEPLOY_RUNS.new"
  mv "$DEPLOY_RUNS.new" "$DEPLOY_RUNS"
}

record started
status=0
"$@" || status=$?
record "exit:$status"
exit "$status"
