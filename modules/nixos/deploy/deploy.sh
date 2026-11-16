# shellcheck shell=bash
# Approve DEPLOY_BRANCH for a set of hosts with one YubiKey-signed fleet tag,
# push it, and have every host build it.
#
#   deploy [--yes] [--allow-rollback] [--no-wait]
#          [--key yk-nfc-deploy|yk-nano-deploy|FILE] [HOST...]
#
# The hosts are DEPLOY_CONTROLLER (this one) and the receivers in
# DEPLOY_RECEIVERS; with no HOST it deploys them all. It fetches origin in
# ~/dotfiles, lists the commits since the oldest of the hosts' last signed
# tags, and asks before signing one deploy/fleet/<UTC time> tag whose "Hosts:"
# line names them all. --yes skips that question, never the touch. If every
# host's last tag is already at the tip, it signs nothing and only starts the
# deploys.
#
# The receivers start at once and in parallel (ssh <host>-agent
# deploy-trigger), with each log line prefixed by the host's name. This host
# first waits for CI to publish the heavy packages it would otherwise compile
# (deploy-wait; --no-wait skips that), then switches with deploy-switch: from
# the tagged commit's objects, so uncommitted changes in ~/dotfiles never
# reach the build, and under the lock bin/rebuild and the receivers use. It
# ends with a line per host and exits 1 if any host failed.
#
# Without --key it signs with the key on whichever deploy YubiKey is plugged
# in (deploy-key), and with yk-nfc-deploy when both are. It picks once, just
# before asking, and only when there's a tag to sign.
#
# Every host refuses a commit that doesn't descend from the one it runs,
# including this one, which checks before waiting for CI and again under the
# lock. --allow-rollback signs "Allow-Rollback: yes" into the tag to permit
# that, and always asks on the terminal. A refusal here fails this host only.
set -euo pipefail
# No replace refs, grafts or commit-graph file: they can fake history (see
# deploy-tag.sh).
export GIT_NO_REPLACE_OBJECTS=1 GIT_GRAFT_FILE=/dev/null
export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=core.commitGraph GIT_CONFIG_VALUE_0=false
# An empty graft file still makes git print its deprecation advice.
export GIT_CONFIG_KEY_1=advice.graftFileDeprecated GIT_CONFIG_VALUE_1=false

: "${DEPLOY_CONTROLLER:?}" "${DEPLOY_RECEIVERS:?}" "${DEPLOY_BRANCH:?}" "${DEPLOY_NIXOS_VERSION:?}"

repo=${DOTFILES:-$HOME/dotfiles}
branch_ref=refs/remotes/origin/$DEPLOY_BRANCH
read -ra fleet <<<"$DEPLOY_CONTROLLER $DEPLOY_RECEIVERS"

usage() {
  echo "usage: deploy [--yes] [--allow-rollback] [--no-wait] [--key yk-nfc-deploy|yk-nano-deploy|FILE] [HOST...]" >&2
  echo "  --key defaults to the deploy key on the plugged-in YubiKey (yk-nfc-deploy if both are)." >&2
  exit 2
}

die() {
  echo "deploy: $*" >&2
  exit 1
}

# No pager: it would take the terminal and swallow the answer to confirm.
g() {
  git -C "$repo" --no-pager "$@"
}

listed() {
  local item=$1 each
  shift
  for each in "$@"; do
    [[ $each == "$item" ]] && return 0
  done
  return 1
}

show_log() {
  g log --no-decorate --format='  %h %<(16,trunc)%an %s' "$@"
}

# A deploy tag also lets that commit's CI publish to the binary cache, so
# workflow changes get their own line.
show_ci_changes() {
  local changed file
  changed=$(g log --format= --name-only "$@" -- .github | sed '/^$/d' | sort -u)
  if [[ -n $changed ]]; then
    echo "These commits change CI, which publishes to the binary cache once the tag is pushed:"
    while IFS= read -r file; do
      echo "  $file"
    done <<<"$changed"
  fi
}

resolve_key() {
  case $key in
  */*) key_file=$key ;;
  *) key_file=$HOME/.ssh/$key ;;
  esac
}

# Ask on the terminal. --yes answers for us, except for a rewritten history
# or a rollback.
confirm() {
  local answer
  if ((yes && !rewritten && !allow_rollback)); then
    return 0
  fi
  if ! { exec 3</dev/tty; } 2>/dev/null; then
    die "needs a terminal to confirm; nothing was signed"
  fi
  read -r -u 3 -p "$1 [y/N] " answer
  exec 3<&-
  [[ $answer == [yY]* ]]
}

yes=0 rewritten=0 allow_rollback=0 wait_for_ci=1 key="" key_file=""
while [[ $# -gt 0 ]]; do
  case $1 in
  -y | --yes)
    yes=1
    shift
    ;;
  --allow-rollback)
    allow_rollback=1
    shift
    ;;
  --no-wait)
    wait_for_ci=0
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
if [[ -n $key ]]; then
  resolve_key
fi
for host in "$@"; do
  listed "$host" "${fleet[@]}" || die "$host doesn't take deploys (hosts: ${fleet[*]})"
done
hosts=()
for host in "${fleet[@]}"; do
  if (($# == 0)) || listed "$host" "$@"; then
    hosts+=("$host")
  fi
done

g fetch --quiet --force --prune --no-tags origin \
  "+refs/heads/$DEPLOY_BRANCH:$branch_ref" \
  "+refs/tags/deploy/*:refs/tags/deploy/*"
target=$(g rev-parse "$branch_ref")

declare -A last_tag=() last_commit=() deploys=() result=()
untagged=() oldest="" oldest_commit="" current=1
for host in "${hosts[@]}"; do
  if last=$(deploy-tag -C "$repo" latest "$host"); then
    read -r tag commit <<<"$last"
    last_tag[$host]=$tag
    last_commit[$host]=$commit
    if [[ -z $oldest || ${tag##*/} < ${oldest##*/} ]]; then
      oldest=$tag oldest_commit=$commit
    fi
    # Old per-host tags approve nothing, so they don't make a host current.
    [[ $commit == "$target" && $tag == deploy/fleet/* ]] || current=0
  else
    untagged+=("$host")
    current=0
  fi
done

if ((current && !allow_rollback)); then
  echo "Each host's last signed tag already approves $DEPLOY_BRANCH at ${target:0:12}; nothing to sign."
  for host in "${hosts[@]}"; do
    deploys[$host]=${last_tag[$host]}
  done
else
  declare -A shown=()
  for host in "${hosts[@]}"; do
    tag=${last_tag[$host]:-}
    if [[ -z $tag || -n ${shown[$tag]:-} ]]; then
      continue
    fi
    shown[$tag]=1
    if ! g merge-base --is-ancestor "${last_commit[$host]}" "$target"; then
      rewritten=1
      echo "$DEPLOY_BRANCH no longer contains $tag (${last_commit[$host]:0:12}). It was rewound or force-pushed."
      echo "Commits that drop out:"
      show_log "$target..${last_commit[$host]}"
    fi
  done
  range=$target
  if ((${#untagged[@]})); then
    echo "No signed deploy tag names ${untagged[*]} yet. The last 20 commits on $DEPLOY_BRANCH:"
    show_log -20 "$target"
  elif g merge-base --is-ancestor "$oldest_commit" "$target"; then
    range=$oldest_commit..$target
    echo "Commits on $DEPLOY_BRANCH since $oldest:"
    show_log "$range"
    g diff --shortstat "$oldest_commit" "$target"
  else
    range=$oldest_commit..$target
    echo "Commits that come in since $oldest:"
    show_log "$range"
  fi
  show_ci_changes "$range"
  if ((allow_rollback)); then
    echo "This tag lets ${hosts[*]} move to ${target:0:12} even if that rolls back the commit they run."
  fi
  if [[ -z $key ]]; then
    key=$(deploy-key) || die "nothing was signed"
    resolve_key
  fi
  confirm "Sign deploy/fleet for ${hosts[*]} at ${target:0:12} with $(basename "$key_file") and deploy it?" ||
    die "cancelled; nothing was signed"
  message=$(
    echo "deploy ${hosts[*]}"
    if ((allow_rollback)); then
      echo "Allow-Rollback: yes"
    fi
    echo
    # A carriage return in a commit subject would make the tag invalid.
    g log --no-decorate --format='%h %s' -50 "$range" | tr -d '\r'
  )
  tag=$(deploy-tag -C "$repo" sign --key "$key_file" --message "$message" "${hosts[@]}" "$target")
  deploy-tag -C "$repo" push --key "$key_file" "$tag"
  echo "Pushed $tag."
  for host in "${hosts[@]}"; do
    deploys[$host]=$tag
  done
fi

logs=$(mktemp -d)
trap 'rm -rf "$logs"' EXIT

# Runs in the background. A deploy goes on on its host whatever happens here.
start_receiver() {
  local host=$1 status=0
  ssh "$host-agent" deploy-trigger </dev/null 2>&1 | tee "$logs/$host.log" | sed -u "s/^/$host: /" ||
    status=$?
  echo "$status" >"$logs/$host.status"
}

for host in "${hosts[@]}"; do
  if [[ $host != "$DEPLOY_CONTROLLER" ]]; then
    echo "Starting the deploy on $host."
    start_receiver "$host" &
  fi
done

if listed "$DEPLOY_CONTROLLER" "${hosts[@]}"; then
  host=$DEPLOY_CONTROLLER
  tag=${deploys[$host]}
  # Recorded once. The wait and the switch hold the tag to this object and
  # to the tip this deploy is for.
  object=$(g rev-parse --verify --quiet "refs/tags/$tag" || true)
  running=$("$DEPLOY_NIXOS_VERSION" --configuration-revision 2>/dev/null || true)
  if ! deploy-tag -C "$repo" approves "$tag" "$host" "$object" "$target"; then
    result[$host]="failed: $tag doesn't approve ${target:0:12} for it; see above"
  elif ! deploy-tag -C "$repo" moves-forward "$tag" "$host" "$running" "$object"; then
    result[$host]="failed: $tag would move it off the commit it runs; see above"
  elif ((wait_for_ci)) &&
    ! deploy-wait -C "$repo" ${key_file:+--key "$key_file"} --commit "$target" "$tag"; then
    result[$host]="not rebuilt: CI hadn't published what it needs"
  else
    echo "Switching $host to $tag."
    status=0
    deploy-switch -C "$repo" --forward --object "$object" --commit "$target" "$tag" "$host" ||
      status=$?
    if ((status == 0)); then
      result[$host]="runs $tag"
    else
      result[$host]="failed: the switch exited $status; see above"
    fi
  fi
fi

wait
for host in "${hosts[@]}"; do
  if [[ $host == "$DEPLOY_CONTROLLER" ]]; then
    continue
  fi
  tag=${deploys[$host]}
  commit=$(g rev-parse "refs/tags/$tag^{commit}")
  status=$(cat "$logs/$host.status" 2>/dev/null || echo unknown)
  if [[ $status != 0 ]]; then
    result[$host]="failed: the deploy exited $status; see its log above"
  elif ! grep -qxF "$host deployed $tag $commit" "$logs/$host.log"; then
    result[$host]="failed: it didn't report deploying $tag; see its log above"
  elif ! grep -qxF "$host runs $commit" "$logs/$host.log"; then
    result[$host]="failed: it deployed $tag but doesn't report running $commit; see its log above"
  else
    result[$host]="runs $tag"
  fi
done

failed=()
echo "Deploy of ${target:0:12}:"
for host in "${hosts[@]}"; do
  echo "  $host ${result[$host]}"
  [[ ${result[$host]} == "runs "* ]] || failed+=("$host")
done
if ((${#failed[@]})); then
  die "failed on ${failed[*]}"
fi
