# shellcheck shell=bash
# ExecStart of deploy-receiver.service: runs the receiver given as arguments and
# keeps a record of each run in DEPLOY_RUNS, keyed by the systemd job that
# started it:
#   <job> <invocation id> started
#   <job> <invocation id> exit:<status>
# The broker hands the job ID to deploy-trigger, which reads the outcome here
# however early or late it looks: systemd unloads the finished unit and forgets
# its Result. DEPLOY_RUNS lives under /run, because job IDs restart at boot.
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
