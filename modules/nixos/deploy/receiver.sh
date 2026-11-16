# shellcheck shell=bash
# Build and switch this host to its newest valid fleet tag naming it. Runs as
# root from deploy-receiver.service and takes no input, so a caller can only
# say "now".
#
# It fetches DEPLOY_BRANCH and the deploy/fleet/* tags over HTTPS into a
# root-owned bare clone. Then it walks the tags whose UTC time is later than
# that of the tag it last deployed, newest first, and picks the first that:
#   - deploy-tag verifies,
#   - names DEPLOY_HOST on its "Hosts:" line (deploy-tag names-host; other
#     hosts' tags are skipped without counting as refused),
#   - points at a commit on DEPLOY_BRANCH,
#   - descends from the commit the host runs now (system.configurationRevision,
#     so a manual rebuild counts too), unless the signed message permits a
#     rollback (deploy-tag moves-forward, the rule `deploy` applies to the
#     controller too),
#   - has a flake.lock that needs no changes.
# It builds that commit, then takes DEPLOY_SWITCH_LOCK, which bin/rebuild
# holds around its own switch, checks the running commit again and only then
# switches. A tag no later than the last deployed one is never deployed, and
# neither is a commit behind the running one, so a withheld or replayed signed
# tag can't roll the host back, even past a manual rebuild that finishes while
# this one builds.
#
# The state file may still name an old deploy/<host>/<UTC time> tag; only its
# UTC time counts. This receiver ignores those tags.
set -euo pipefail
export LC_ALL=C
# No replace refs, grafts or commit-graph file: they can fake history (see
# deploy-tag.sh).
export GIT_NO_REPLACE_OBJECTS=1 GIT_GRAFT_FILE=/dev/null
export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=core.commitGraph GIT_CONFIG_VALUE_0=false
# An empty graft file still makes git print its deprecation advice.
export GIT_CONFIG_KEY_1=advice.graftFileDeprecated GIT_CONFIG_VALUE_1=false

: "${DEPLOY_HOST:?}" "${DEPLOY_REPO_URL:?}" "${DEPLOY_BRANCH:?}" "${DEPLOY_STATE_DIR:?}"
: "${DEPLOY_NIXOS_VERSION:?}" "${DEPLOY_SWITCH_LOCK:?}"

repo=$DEPLOY_STATE_DIR/dotfiles.git
state=$DEPLOY_STATE_DIR/deployed
branch_ref=refs/heads/$DEPLOY_BRANCH
stamp_re='^[0-9]{8}T[0-9]{6}Z$'

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
if ! deploy-tag -C "$repo" moves-forward "$chosen" "$DEPLOY_HOST" "$(running_commit)"; then
  echo "deploy-receiver: $DEPLOY_HOST changed while $chosen was building; not switching" >&2
  exit 1
fi
nixos-rebuild switch --store-path "$system"
printf '%s %s\n' "$chosen" "$commit" >"$state.new"
mv "$state.new" "$state"
echo "$DEPLOY_HOST now runs $chosen"
