# shellcheck shell=bash
# Build and switch this host to its newest valid deploy tag. Runs as root from
# deploy-receiver.service and takes no input, so a caller can only say "now".
#
# It fetches DEPLOY_BRANCH and the deploy/DEPLOY_HOST/* tags over HTTPS into a
# root-owned bare clone. Then it walks the tags newer than the one it last
# deployed, newest first, and switches to the first that:
#   - deploy-tag verifies,
#   - points at a commit on DEPLOY_BRANCH,
#   - descends from the commit the host runs now (system.configurationRevision,
#     so a manual rebuild counts too), unless the signed tag message carries
#     "Allow-Rollback: yes" in its first paragraph,
#   - has a flake.lock that needs no changes.
# Older tag names are never deployed, and neither is a commit behind the
# running one, so a withheld or replayed signed tag can't roll the host back.
set -euo pipefail
export LC_ALL=C

: "${DEPLOY_HOST:?}" "${DEPLOY_REPO_URL:?}" "${DEPLOY_BRANCH:?}" "${DEPLOY_STATE_DIR:?}" "${DEPLOY_NIXOS_VERSION:?}"

repo=$DEPLOY_STATE_DIR/dotfiles.git
state=$DEPLOY_STATE_DIR/deployed
branch_ref=refs/heads/$DEPLOY_BRANCH

refuse() {
  echo "deploy-receiver: refusing $1: $2" >&2
}

# The override must sit in the message's first paragraph, which `deploy`
# writes; the commit list after it can't produce the line.
allows_rollback() {
  local message
  message=$(git -C "$repo" cat-file tag "$1")
  awk 'body && /^$/ { exit } body && $0 == "Allow-Rollback: yes" { found = 1 } !body && /^$/ { body = 1 }
    END { exit !found }' <<<"$message"
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
# A dirty manual rebuild reports <commit>-dirty; its base commit is the floor.
running=$("$DEPLOY_NIXOS_VERSION" --configuration-revision 2>/dev/null || true)
running=${running%-dirty}
if [[ ! $running =~ ^[0-9a-f]{40}$ ]]; then
  running=""
fi

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
  if ! allows_rollback "$ref"; then
    if [[ -z $running ]]; then
      refuse "$tag" "can't read the commit $DEPLOY_HOST runs; deploying needs a tag signed with --allow-rollback"
      refused=1
      continue
    fi
    if ! git -C "$repo" merge-base --is-ancestor "$running" "$commit" 2>/dev/null; then
      refuse "$tag" "$commit doesn't descend from $running, which $DEPLOY_HOST runs; a rollback needs a tag signed with --allow-rollback"
      refused=1
      continue
    fi
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

echo "Deploying $chosen ($commit) to $DEPLOY_HOST"
# --no-write-lock-file is left out on purpose: in Nix 2.34 it turns the
# refusal from --no-update-lock-file back into a warning.
nixos-rebuild switch --no-update-lock-file --flake "git+file://$repo?rev=$commit#$DEPLOY_HOST"
printf '%s %s\n' "$chosen" "$commit" >"$state.new"
mv "$state.new" "$state"
echo "$DEPLOY_HOST now runs $chosen"
