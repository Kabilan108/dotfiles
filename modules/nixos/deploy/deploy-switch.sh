# shellcheck shell=bash
# Switch this host to a signed fleet tag's commit under DEPLOY_SWITCH_LOCK,
# the lock the receivers and bin/rebuild switch under. `deploy` runs it for
# the controller, and bin/rebuild for a clean build of a signed HEAD.
#
#   deploy-switch [-C DIR] [--forward] --object OBJECT --commit COMMIT
#                 TAG HOST [switch|test|boot]
#
# OBJECT and COMMIT are the tag object and commit the caller recorded when it
# signed or checked TAG. Before asking sudo for the lock, and again once it
# holds it, this requires `deploy-tag approves`: TAG still resolves to OBJECT,
# which verifies, names HOST on its "Hosts:" line and points at COMMIT. Then
# it builds COMMIT straight from the repository's objects
# (git+file://DIR?rev=COMMIT, with --no-update-lock-file), never whatever TAG
# names by then, so neither the work tree nor a moved tag reaches the build.
#
# --forward adds the receivers' ancestry rule, deploy-tag moves-forward:
# COMMIT must descend from the commit this host runs, unless OBJECT allows a
# rollback. A switch that finishes while this one waits for the lock counts.
# The checks under the lock run as the calling user, in the repository that
# user owns.
set -euo pipefail

: "${DEPLOY_SWITCH_LOCK:?}" "${DEPLOY_NIXOS_VERSION:?}"

usage() {
  echo "usage: deploy-switch [-C DIR] [--forward] --object OBJECT --commit COMMIT TAG HOST [switch|test|boot]" >&2
  exit 2
}

running() {
  "$DEPLOY_NIXOS_VERSION" --configuration-revision 2>/dev/null || true
}

# As root, holding the lock (see the end of this file).
if [[ ${1:-} == --locked ]]; then
  [[ $# -eq 10 ]] || usage
  user=$2 forward=$3 top=$4 tag=$5 host=$6 object=$7 commit=$8 action=$9 deploy_tag=${10}
  as_user() {
    runuser -u "$user" -- "$deploy_tag" -C "$top" "$@"
  }
  if ! as_user approves "$tag" "$host" "$object" "$commit"; then
    echo "deploy-switch: $tag changed while this switch waited for the lock; not switching" >&2
    exit 1
  fi
  if ((forward)) && ! as_user moves-forward "$tag" "$host" "$(running)" "$object"; then
    echo "deploy-switch: $host changed while this switch waited for the lock; not switching" >&2
    exit 1
  fi
  exec nixos-rebuild "$action" --no-update-lock-file --flake "git+file://$top?rev=$commit#$host"
fi

repo=. forward=0 object="" commit=""
while [[ $# -gt 0 ]]; do
  case $1 in
  -C)
    [[ -n ${2:-} ]] || usage
    repo=$2
    shift 2
    ;;
  --forward)
    forward=1
    shift
    ;;
  --object)
    [[ -n ${2:-} ]] || usage
    object=$2
    shift 2
    ;;
  --commit)
    [[ -n ${2:-} ]] || usage
    commit=$2
    shift 2
    ;;
  -*) usage ;;
  *) break ;;
  esac
done
[[ -n $object && -n $commit ]] || usage
[[ $# -eq 2 || $# -eq 3 ]] || usage
tag=$1 host=$2 action=${3:-switch}
case $action in
switch | test | boot) ;;
*) usage ;;
esac

top=$(git -C "$repo" rev-parse --show-toplevel)
deploy-tag -C "$repo" approves "$tag" "$host" "$object" "$commit" || exit 1
if ((forward)) && ! deploy-tag -C "$repo" moves-forward "$tag" "$host" "$(running)" "$object"; then
  exit 1
fi
sudo flock "$DEPLOY_SWITCH_LOCK" "$BASH" "$0" --locked "$(id -un)" "$forward" "$top" "$tag" "$host" \
  "$object" "$commit" "$action" "$(command -v deploy-tag)"
