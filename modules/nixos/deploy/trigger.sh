# shellcheck shell=bash
# Start a deploy through the deploy-trigger socket, print its log, and exit
# with the receiver's status. Laptop agents run it over SSH; only members of
# the deploy-trigger group may connect. The status counts only as the very
# last line, so log output can't fake one.
set -euo pipefail

status=""
while IFS= read -r line; do
  if [[ $line =~ ^deploy-trigger-status\ ([0-9]+)$ ]]; then
    status=${BASH_REMATCH[1]}
  else
    status=""
    printf '%s\n' "$line"
  fi
done < <(socat -u "UNIX-CONNECT:$DEPLOY_TRIGGER_SOCKET" -)

if [[ -z $status ]]; then
  echo "deploy-trigger: the connection closed before the deploy reported a result" >&2
  exit 1
fi
exit "$status"
