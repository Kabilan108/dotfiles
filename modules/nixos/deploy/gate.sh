# shellcheck shell=bash
# Forced command for agent keys on hosts in lib/fleet.nix
# deploy.gatedAgentLogins. They may start a deploy or list sessions for
# sessionizer, and nothing else.
set -euo pipefail

# shellcheck disable=SC2016 # sessionizer sends exactly this string
inventory_command='"$HOME/bin/sessionizer" --inventory'

case ${SSH_ORIGINAL_COMMAND:-} in
deploy-trigger) exec deploy-trigger ;;
"$inventory_command") exec "$DEPLOY_GATE_SESSIONIZER" --inventory ;;
*)
  echo "deploy-gate: not allowed: ${SSH_ORIGINAL_COMMAND:-interactive login}" >&2
  exit 1
  ;;
esac
