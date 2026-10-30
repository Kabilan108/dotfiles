# shellcheck shell=bash
# Runs as root once per connection to the deploy-trigger socket, for at most
# RuntimeMaxSec. It queues deploy-receiver.service with a fixed job mode
# without waiting for it, replies with the job ID and exits. The receiver
# never depends on the caller, and a caller that never reads can't hold a
# connection slot. It reads nothing from the caller.
#
# StartUnit returns the job it queued, or the pending job it joined, so the ID
# names the run that serves this request.
set -euo pipefail

if reply=$(busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 \
  org.freedesktop.systemd1.Manager StartUnit ss deploy-receiver.service replace) &&
  [[ $reply =~ /job/([0-9]+)\"$ ]]; then
  echo "deploy-trigger: queued job ${BASH_REMATCH[1]}"
else
  echo "deploy-trigger: couldn't queue deploy-receiver.service"
fi
