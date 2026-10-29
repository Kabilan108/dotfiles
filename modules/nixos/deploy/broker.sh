# shellcheck shell=bash
# Runs as root once per connection to the deploy-trigger socket, for at most
# RuntimeMaxSec. It queues deploy-receiver.service with a fixed job mode
# without waiting for it, writes one line and exits. The receiver never depends
# on the caller, and a caller that never reads can't hold a connection slot.
# It reads nothing from the caller.
set -euo pipefail

if systemctl start --no-block --job-mode=replace deploy-receiver.service; then
  echo "deploy-trigger: started"
else
  echo "deploy-trigger: couldn't queue deploy-receiver.service"
fi
