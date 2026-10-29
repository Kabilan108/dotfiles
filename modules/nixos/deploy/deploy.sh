# shellcheck shell=bash
# Approve DEPLOY_BRANCH for a host with a YubiKey-signed tag, push the tag,
# and have the host build it.
#
#   deploy [--yes] [--key yk-nfc|yk-nano|FILE] HOST
#
# It fetches origin in ~/dotfiles, lists the commits since HOST's last signed
# deploy tag, and asks before signing. --yes skips that question, never the
# touch. With nothing new it only starts the deploy on HOST.
set -euo pipefail

: "${DEPLOY_HOSTS:?}" "${DEPLOY_BRANCH:?}"

repo=${DOTFILES:-$HOME/dotfiles}
branch_ref=refs/remotes/origin/$DEPLOY_BRANCH

usage() {
  echo "usage: deploy [--yes] [--key yk-nfc|yk-nano|FILE] HOST" >&2
  exit 2
}

die() {
  echo "deploy: $*" >&2
  exit 1
}

g() {
  git -C "$repo" "$@"
}

show_log() {
  g log --no-decorate --format='  %h %<(16,trunc)%an %s' "$@"
}

# Ask on the terminal. --yes answers for us unless the history was rewritten.
confirm() {
  local answer
  if ((yes && !rewritten)); then
    return 0
  fi
  if ! { exec 3</dev/tty; } 2>/dev/null; then
    die "needs a terminal to confirm; nothing was signed"
  fi
  read -r -u 3 -p "$1 [y/N] " answer
  exec 3<&-
  [[ $answer == [yY]* ]]
}

yes=0 rewritten=0 key=yk-nfc
while [[ $# -gt 0 ]]; do
  case $1 in
  -y | --yes)
    yes=1
    shift
    ;;
  --key)
    [[ -n ${2:-} ]] || usage
    key=$2
    shift 2
    ;;
  -*) usage ;;
  *) break ;;
  esac
done
[[ $# -eq 1 ]] || usage
host=$1
[[ " $DEPLOY_HOSTS " == *" $host "* ]] || die "$host doesn't take deploys (receivers: $DEPLOY_HOSTS)"
case $key in
*/*) key_file=$key ;;
*) key_file=$HOME/.ssh/$key ;;
esac

g fetch --quiet --force --prune --no-tags origin \
  "+refs/heads/$DEPLOY_BRANCH:$branch_ref" \
  "+refs/tags/deploy/$host/*:refs/tags/deploy/$host/*"
target=$(g rev-parse "$branch_ref")

last_tag="" last_commit=""
if last=$(deploy-tag -C "$repo" latest "$host"); then
  read -r last_tag last_commit <<<"$last"
fi

if [[ $last_commit == "$target" ]]; then
  echo "$last_tag already approves $DEPLOY_BRANCH at ${target:0:12}; nothing to sign."
  tag=$last_tag
else
  range=$target
  if [[ -z $last_tag ]]; then
    echo "$host has no signed deploy tag yet. The last 20 commits on $DEPLOY_BRANCH:"
    show_log -20 "$target"
  elif g merge-base --is-ancestor "$last_commit" "$target"; then
    range=$last_commit..$target
    echo "Commits on $DEPLOY_BRANCH since $last_tag:"
    show_log "$range"
    g diff --shortstat "$last_commit" "$target"
  else
    rewritten=1
    range=$last_commit..$target
    echo "$DEPLOY_BRANCH no longer contains $last_tag (${last_commit:0:12}). It was rewound or force-pushed."
    echo "Commits that drop out:"
    show_log "$target..$last_commit"
    echo "Commits that come in:"
    show_log "$range"
  fi
  confirm "Sign deploy/$host at ${target:0:12} and deploy it?" || die "cancelled; nothing was signed"
  message=$(
    echo "deploy $host"
    echo
    g log --no-decorate --format='%h %s' -50 "$range"
  )
  tag=$(deploy-tag -C "$repo" sign --key "$key_file" --message "$message" "$host" "$target")
  g push --quiet origin "refs/tags/$tag"
  echo "Pushed $tag."
fi

echo "Starting the deploy on $host."
out=$(mktemp)
trap 'rm -f "$out"' EXIT
status=0
ssh "$host-agent" deploy-trigger 2>&1 | tee "$out" || status=$?
((status == 0)) || die "the deploy on $host failed (exit $status)"
grep -qxF "$host runs $tag $(g rev-parse "refs/tags/$tag^{commit}")" "$out" ||
  die "$host didn't report running $tag; see its log above"
echo "$host runs $tag."
