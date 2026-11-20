# shellcheck shell=bash
set -euo pipefail
export LC_ALL=C

: "${DEPLOY_HOST:?}" "${DEPLOY_REPO_URL:?}" "${DEPLOY_BRANCH:?}" "${DEPLOY_STATE_DIR:?}"
: "${DEPLOY_NIXOS_VERSION:?}" "${DEPLOY_SWITCH_LOCK:?}"

repo=$DEPLOY_STATE_DIR/dotfiles.git
state=$DEPLOY_STATE_DIR/deployed
branch_ref=refs/heads/$DEPLOY_BRANCH
stamp_re='^[0-9]{8}T[0-9]{6}Z$'

refuse() {
  echo "deploy-receiver: refusing $1: $2" >&2
}

running_commit() {
  local rev
  rev=$("$DEPLOY_NIXOS_VERSION" --configuration-revision 2>/dev/null || true)
  rev=${rev%-dirty}
  if [[ $rev =~ ^[0-9a-f]{40}$ ]]; then
    echo "$rev"
  fi
}

if [[ ! -d $repo ]]; then
  git init --quiet --bare --initial-branch="$DEPLOY_BRANCH" "$repo"
fi
git -C "$repo" fetch --quiet --force --prune --no-tags "$DEPLOY_REPO_URL" \
  "+refs/heads/$DEPLOY_BRANCH:$branch_ref" \
  "+refs/tags/deploy/fleet/*:refs/tags/deploy/fleet/*"

deployed="" deployed_at=""
if [[ -s $state ]]; then
  read -r deployed _ <"$state"
  deployed_at=${deployed##*/}
  if [[ ! $deployed =~ ^deploy/[a-z0-9-]+/ || ! $deployed_at =~ $stamp_re ]]; then
    echo "deploy-receiver: can't read the last deployed tag from $state: $deployed" >&2
    exit 1
  fi
fi
running=$(running_commit)

chosen="" commit="" refused=0
while read -r ref; do
  tag=${ref#refs/tags/}
  if [[ -n $deployed && ! ${tag##*/} > $deployed_at ]]; then
    break
  fi
  if ! deploy-tag -C "$repo" verify "$tag"; then
    refused=1
    continue
  fi
  if ! deploy-tag -C "$repo" names-host "$tag" "$DEPLOY_HOST"; then
    continue
  fi
  commit=$(git -C "$repo" rev-parse "$ref^{commit}")
  if ! git -C "$repo" merge-base --is-ancestor "$commit" "$branch_ref"; then
    refuse "$tag" "$commit is not on $DEPLOY_BRANCH"
    refused=1
    continue
  fi
  if ! deploy-tag -C "$repo" moves-forward "$tag" "$DEPLOY_HOST" "$running"; then
    refused=1
    continue
  fi
  if ! git -C "$repo" cat-file -e "$commit:flake.lock" 2>/dev/null; then
    refuse "$tag" "$commit has no flake.lock"
    refused=1
    continue
  fi
  if ! nix flake metadata --no-update-lock-file "git+file://$repo?rev=$commit" >/dev/null; then
    refuse "$tag" "the flake.lock at $commit is out of date"
    refused=1
    continue
  fi
  chosen=$tag
  break
done < <(git -C "$repo" for-each-ref --sort=-refname --format='%(refname)' refs/tags/deploy/fleet/)

if [[ -z $chosen ]]; then
  if ((refused)); then
    echo "deploy-receiver: no valid deploy tag for $DEPLOY_HOST newer than ${deployed:-nothing}" >&2
    exit 1
  fi
  if [[ -z $deployed ]]; then
    echo "deploy-receiver: no deploy tag names $DEPLOY_HOST yet" >&2
    exit 1
  fi
  echo "No deploy tag for $DEPLOY_HOST newer than $deployed; it runs ${running:-an unknown commit}"
  exit 0
fi

echo "Building $chosen ($commit) for $DEPLOY_HOST"
cd "$DEPLOY_STATE_DIR"
nixos-rebuild build --no-update-lock-file --flake "git+file://$repo?rev=$commit#$DEPLOY_HOST"
system=$(readlink -f result)

saved_umask=$(umask)
umask 077
exec 9>>"$DEPLOY_SWITCH_LOCK"
umask "$saved_umask"
if ! flock --nonblock 9; then
  echo "Waiting for a manual rebuild to finish"
  flock 9
fi
if ! deploy-tag -C "$repo" moves-forward "$chosen" "$DEPLOY_HOST" "$(running_commit)"; then
  echo "deploy-receiver: $DEPLOY_HOST changed while $chosen was building; not switching" >&2
  exit 1
fi
nixos-rebuild switch --store-path "$system"
printf '%s %s\n' "$chosen" "$commit" >"$state.new"
mv "$state.new" "$state"
echo "$DEPLOY_HOST now runs $chosen"
