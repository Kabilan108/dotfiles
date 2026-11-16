# shellcheck shell=bash
# Switch this host to a signed tag's commit under DEPLOY_SWITCH_LOCK, the lock
# the receivers and bin/rebuild switch under. `deploy` runs it for the
# controller, and bin/rebuild for a clean build of a signed HEAD.
#
#   deploy-switch [-C DIR] [--forward] TAG HOST [switch|test|boot]
#
# It builds TAG's commit straight from the repository's objects
# (git+file://DIR?rev=COMMIT, with --no-update-lock-file), so neither the work
# tree nor a later change to it reaches the build.
#
# --forward applies the receivers' rule, deploy-tag moves-forward: TAG's
# commit must descend from the commit this host runs, unless TAG allows a
# rollback. It checks before asking sudo for the lock and again once it holds
# the lock, so a switch that finishes while this one waits for it counts. The
# second check runs as the calling user, in the repository that user owns.
set -euo pipefail

: "${DEPLOY_SWITCH_LOCK:?}" "${DEPLOY_NIXOS_VERSION:?}"

usage() {
  echo "usage: deploy-switch [-C DIR] [--forward] TAG HOST [switch|test|boot]" >&2
  exit 2
}

running() {
  "$DEPLOY_NIXOS_VERSION" --configuration-revision 2>/dev/null || true
}

# As root, holding the lock (see the end of this file).
if [[ ${1:-} == --locked ]]; then
  [[ $# -eq 9 ]] || usage
  user=$2 forward=$3 repo=$4 tag=$5 host=$6 action=$7 flake=$8 deploy_tag=$9
  if ((forward)) &&
    ! runuser -u "$user" -- "$deploy_tag" -C "$repo" moves-forward "$tag" "$host" "$(running)"; then
    echo "deploy-switch: $host changed while this switch waited for the lock; not switching" >&2
    exit 1
  fi
  exec nixos-rebuild "$action" --no-update-lock-file --flake "$flake"
fi

repo=. forward=0
if [[ ${1:-} == -C ]]; then
  [[ $# -ge 2 ]] || usage
  repo=$2
  shift 2
fi
if [[ ${1:-} == --forward ]]; then
  forward=1
  shift
fi
[[ $# -eq 2 || $# -eq 3 ]] || usage
tag=$1 host=$2 action=${3:-switch}
case $action in
switch | test | boot) ;;
*) usage ;;
esac

commit=$(git -C "$repo" rev-parse --verify --quiet "refs/tags/$tag^{commit}") || {
  echo "deploy-switch: no tag $tag in $repo" >&2
  exit 1
}
top=$(git -C "$repo" rev-parse --show-toplevel)
if ((forward)) && ! deploy-tag -C "$repo" moves-forward "$tag" "$host" "$(running)"; then
  exit 1
fi
sudo flock "$DEPLOY_SWITCH_LOCK" "$BASH" "$0" --locked "$(id -un)" "$forward" "$top" "$tag" "$host" \
  "$action" "git+file://$top?rev=$commit#$host" "$(command -v deploy-tag)"
