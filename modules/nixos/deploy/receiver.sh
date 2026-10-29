# shellcheck shell=bash
# Build and switch this host to its newest valid deploy tag. Runs as root from
# deploy-receiver.service and takes no input, so a caller can only say "now".
#
# It fetches DEPLOY_BRANCH and the deploy/DEPLOY_HOST/* tags over HTTPS into a
# root-owned bare clone. Then it walks the tags newer than the one it last
# deployed, newest first, and switches to the first that deploy-tag verifies
# and whose commit is on DEPLOY_BRANCH. It never goes back to an older tag, so
# replaying an old signed tag can't roll the host back.
set -euo pipefail
export LC_ALL=C

: "${DEPLOY_HOST:?}" "${DEPLOY_REPO_URL:?}" "${DEPLOY_BRANCH:?}" "${DEPLOY_STATE_DIR:?}"

repo=$DEPLOY_STATE_DIR/dotfiles.git
state=$DEPLOY_STATE_DIR/deployed
branch_ref=refs/heads/$DEPLOY_BRANCH

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
    echo "deploy-receiver: refusing $tag: $commit is not on $DEPLOY_BRANCH" >&2
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
  echo "$DEPLOY_HOST already runs $deployed"
  exit 0
fi

echo "Deploying $chosen ($commit) to $DEPLOY_HOST"
nixos-rebuild switch --flake "git+file://$repo?rev=$commit#$DEPLOY_HOST"
printf '%s %s\n' "$chosen" "$commit" >"$state.new"
mv "$state.new" "$state"
echo "$DEPLOY_HOST now runs $chosen"
