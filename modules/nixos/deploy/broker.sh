# shellcheck shell=bash
set -euo pipefail

if reply=$(busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 \
  org.freedesktop.systemd1.Manager StartUnit ss deploy-receiver.service replace) &&
  [[ $reply =~ /job/([0-9]+)\"$ ]]; then
  echo "deploy-trigger: queued job ${BASH_REMATCH[1]}"
else
  echo "deploy-trigger: couldn't queue deploy-receiver.service"
fi
