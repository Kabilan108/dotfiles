# shellcheck shell=bash
# Build and switch this host to its newest valid deploy tag. Runs as root from
# deploy-receiver.service and takes no input, so a caller can only say "now".
#
# It fetches DEPLOY_BRANCH and the deploy/DEPLOY_HOST/* tags over HTTPS into a
# root-owned bare clone. Then it walks the tags newer than the one it last
# deployed, newest first, and picks the first that:
#   - deploy-tag verifies,
#   - points at a commit on DEPLOY_BRANCH,
#   - descends from the commit the host runs now (system.configurationRevision,
#     so a manual rebuild counts too), unless deploy-tag allows-rollback says
#     the signed message permits a rollback,
#   - has a flake.lock that needs no changes.
# It builds that commit, then takes DEPLOY_SWITCH_LOCK, which bin/rebuild
# holds around its own switch, checks the running commit again and only then
# switches. Older tag names are never deployed, and neither is a commit behind
# the running one, so a withheld or replayed signed tag can't roll the host
# back, even past a manual rebuild that finishes while this one builds.
set -euo pipefail
export LC_ALL=C

: "${DEPLOY_HOST:?}" "${DEPLOY_REPO_URL:?}" "${DEPLOY_BRANCH:?}" "${DEPLOY_STATE_DIR:?}"
: "${DEPLOY_NIXOS_VERSION:?}" "${DEPLOY_SWITCH_LOCK:?}"

repo=$DEPLOY_STATE_DIR/dotfiles.git
state=$DEPLOY_STATE_DIR/deployed
branch_ref=refs/heads/$DEPLOY_BRANCH

# deploy-trigger follows this run without privileges, and systemd unloads the
# unit, with its Result, as soon as it ends. So record this run's exit status.
record_run() {
  local status=$?
  printf '%s %s\n' "${INVOCATION_ID:-}" "$status" >"$DEPLOY_STATE_DIR/last-run.new"
  mv "$DEPLOY_STATE_DIR/last-run.new" "$DEPLOY_STATE_DIR/last-run"
}
trap record_run EXIT

refuse() {
  echo "deploy-receiver: refusing $1: $2" >&2
}

# The commit this host runs, without the -dirty suffix a dirty manual rebuild
# reports, or nothing if it can't tell.
running_commit() {
  local rev
  rev=$("$DEPLOY_NIXOS_VERSION" --configuration-revision 2>/dev/null || true)
  rev=${rev%-dirty}
  if [[ $rev =~ ^[0-9a-f]{40}$ ]]; then
    echo "$rev"
  fi
}

# Whether a tag may take this host from the running commit to its commit.
moves_forward() {
  local tag=$1 commit=$2 running=$3
  if deploy-tag -C "$repo" allows-rollback "$tag"; then
    return 0
  fi
  if [[ -z $running ]]; then
    refuse "$tag" "can't read the commit $DEPLOY_HOST runs; deploying needs a tag signed with --allow-rollback"
    return 1
  fi
  if ! git -C "$repo" merge-base --is-ancestor "$running" "$commit" 2>/dev/null; then
    refuse "$tag" "$commit doesn't descend from $running, which $DEPLOY_HOST runs; a rollback needs a tag signed with --allow-rollback"
    return 1
  fi
}

if [[ ! -d $repo ]]; then
  git init --quiet --bare --initial-branch="$DEPLOY_BRANCH" "$repo"
fi
git -C "$repo" fetch --quiet --force --prune --no-tags "$DEPLOY_REPO_URL" \
  "+refs/heads/$DEPLOY_BRANCH:$branch_ref" \
  "+refs/tags/deploy/$DEPLOY_HOST/*:refs/tags/deploy/$DEPLOY_HOST/*"

deployed=""
if [[ -s $state ]]; then
  read -r deployed _ <"$state"
fi
running=$(running_commit)

chosen="" commit="" refused=0
while read -r ref; do
  tag=${ref#refs/tags/}
  if [[ -n $deployed && ! $tag > $deployed ]]; then
    break
  fi
  if ! deploy-tag -C "$repo" verify "$tag"; then
    refused=1
    continue
  fi
  commit=$(git -C "$repo" rev-parse "$ref^{commit}")
  if ! git -C "$repo" merge-base --is-ancestor "$commit" "$branch_ref"; then
    refuse "$tag" "$commit is not on $DEPLOY_BRANCH"
    refused=1
    continue
  fi
  if ! moves_forward "$tag" "$commit" "$running"; then
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
done < <(git -C "$repo" for-each-ref --sort=-refname --format='%(refname)' "refs/tags/deploy/$DEPLOY_HOST/")

if [[ -z $chosen ]]; then
  if ((refused)); then
    echo "deploy-receiver: no valid deploy tag newer than ${deployed:-nothing} for $DEPLOY_HOST" >&2
    exit 1
  fi
  if [[ -z $deployed ]]; then
    echo "deploy-receiver: $DEPLOY_HOST has no deploy tags yet" >&2
    exit 1
  fi
  echo "No deploy tag newer than $deployed; $DEPLOY_HOST runs ${running:-an unknown commit}"
  exit 0
fi

# Build first, outside the lock. The result link in the state directory keeps
# the system from garbage collection until the switch. --no-write-lock-file is
# left out on purpose: in Nix 2.34 it turns the refusal from
# --no-update-lock-file back into a warning.
echo "Building $chosen ($commit) for $DEPLOY_HOST"
cd "$DEPLOY_STATE_DIR"
nixos-rebuild build --no-update-lock-file --flake "git+file://$repo?rev=$commit#$DEPLOY_HOST"
system=$(readlink -f result)

# Root-only, so nobody else can hold it.
saved_umask=$(umask)
umask 077
exec 9>>"$DEPLOY_SWITCH_LOCK"
umask "$saved_umask"
if ! flock --nonblock 9; then
  echo "Waiting for a manual rebuild to finish"
  flock 9
fi
if ! moves_forward "$chosen" "$commit" "$(running_commit)"; then
  echo "deploy-receiver: $DEPLOY_HOST changed while $chosen was building; not switching" >&2
  exit 1
fi
nixos-rebuild switch --store-path "$system"
printf '%s %s\n' "$chosen" "$commit" >"$state.new"
mv "$state.new" "$state"
echo "$DEPLOY_HOST now runs $chosen"
