# shellcheck shell=bash
set -euo pipefail

: "${DEPLOY_SWITCH_LOCK:?}" "${DEPLOY_NIXOS_VERSION:?}"

usage() {
  echo "usage: deploy-switch [-C DIR] [--forward] --object OBJECT --commit COMMIT TAG HOST [switch|test|boot]" >&2
  exit 2
}

running() {
  "$DEPLOY_NIXOS_VERSION" --configuration-revision 2>/dev/null || true
}

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
