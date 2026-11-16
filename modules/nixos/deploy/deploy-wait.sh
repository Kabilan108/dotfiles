# shellcheck shell=bash
# Hold a signed rebuild of this host until CI has published the heavy packages
# it would otherwise compile. `deploy` and bin/rebuild run it on the
# controller before they switch.
#
#   deploy-wait [-C DIR] [--key FILE] TAG
#
# A tag that isn't on DEPLOY_REPO_URL started no CI run, such as one whose
# push failed, so it says how to push it, with the signing key FILE when the
# caller knows it, and exits 0 without waiting.
#
# Otherwise it runs `ci/cache-targets.py heavy` from TAG's commit, which
# evaluates only this host's system at that commit and lists the packages
# marked "# wait" in ci/cache-packages with an output in neither the local
# store nor the binary cache. With none it exits 0 at once. Otherwise it finds
# the run of the cache workflow that TAG's push started (a tag push runs with
# the tag as its branch) and waits for the "build <package>" job of each
# listed package. A package has no job when the plan found it cached; the
# script counts it so only once the build matrix exists or the run succeeded.
#
# Exits 0 to build. If a job fails, CI can't be read, no run turns up within
# DEPLOY_WAIT_FIND seconds, DEPLOY_WAIT_TIMEOUT seconds pass, or on Ctrl-C, it
# asks on the terminal whether to build locally anyway, and exits 1 without a
# terminal or a yes. GitHub is polled every DEPLOY_WAIT_POLL seconds.
set -euo pipefail

: "${DEPLOY_GITHUB_REPO:?DEPLOY_GITHUB_REPO must name the GitHub repo, as owner/name}"
: "${DEPLOY_REPO_URL:?DEPLOY_REPO_URL must name the repo the tags are pushed to}"
poll=${DEPLOY_WAIT_POLL:-20}
find_for=${DEPLOY_WAIT_FIND:-120}
timeout=${DEPLOY_WAIT_TIMEOUT:-3600}

usage() {
  echo "usage: deploy-wait [-C DIR] [--key FILE] TAG" >&2
  exit 2
}

if [[ ! $poll$find_for$timeout =~ ^[0-9]+$ ]]; then
  echo "deploy-wait: DEPLOY_WAIT_POLL, DEPLOY_WAIT_FIND and DEPLOY_WAIT_TIMEOUT must be whole seconds" >&2
  exit 2
fi

repo=. key_file=""
if [[ ${1:-} == -C ]]; then
  [[ $# -ge 2 ]] || usage
  repo=$2
  shift 2
fi
if [[ ${1:-} == --key ]]; then
  [[ -n ${2:-} ]] || usage
  key_file=$2
  shift 2
fi
[[ $# -eq 1 ]] || usage
tag=$1

interrupted=0
trap 'interrupted=1' INT

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Ends the script: 0 if the answer on the terminal is yes, else 1.
give_up() {
  local answer=""
  trap - INT
  if ((interrupted)); then
    echo "Stopped waiting for CI."
  else
    echo "$1"
  fi
  if ! { exec 3</dev/tty; } 2>/dev/null; then
    echo "deploy-wait: no terminal to ask whether to build locally; not building" >&2
    exit 1
  fi
  read -r -u 3 -p "Build locally anyway? [y/N] " answer || true
  exec 3<&-
  [[ $answer == [yY]* ]] || exit 1
  exit 0
}

pause() {
  sleep "$1" || true
}

commit=$(git -C "$repo" rev-parse --verify --quiet "refs/tags/$tag^{commit}") ||
  give_up "deploy-wait: no tag $tag in $repo."
top=$(git -C "$repo" rev-parse --show-toplevel)

# --exit-code makes 2 mean "no such ref"; anything else unexpected leaves it
# to the run lookup below.
on_remote=0
git ls-remote --exit-code "$DEPLOY_REPO_URL" "refs/tags/$tag" >/dev/null || on_remote=$?
if ((on_remote == 2)); then
  echo "$tag isn't on GitHub, so no CI run builds for it. Building without waiting."
  echo "Push it with: deploy-tag -C $top push --key ${key_file:-<its key file>} $tag"
  exit 0
fi

# The planner and its package list come from the tagged commit, never from
# the work tree, and it evaluates that commit from the repository's objects.
echo "Checking which heavy packages $tag would compile here."
if ! git -C "$repo" archive "$commit" ci | tar -x -C "$work" ||
  ! planned=$(python3 "$work/ci/cache-targets.py" heavy "git+file://$top?rev=$commit") ||
  ! names=$(jq -r 'if type == "array" and all(.[]; type == "string") then .[] else error("not a list of names") end' <<<"$planned"); then
  give_up "Couldn't tell which heavy packages $tag needs."
fi
if [[ -z $names ]]; then
  echo "Every heavy package is in the local store or the cache."
  exit 0
fi
mapfile -t pending <<<"$names"
echo "Without CI this build would compile: ${pending[*]}"

run_id="" url=""
deadline=$((SECONDS + find_for))
while :; do
  if runs=$(gh run list --repo "$DEPLOY_GITHUB_REPO" --workflow cache.yml --branch "$tag" \
    --event push --json databaseId,url --limit 1 2>"$work/gh-error") &&
    run_id=$(jq -r '.[0].databaseId // empty' <<<"$runs") && [[ -n $run_id ]]; then
    url=$(jq -r '.[0].url' <<<"$runs")
    break
  fi
  if ((interrupted || SECONDS >= deadline)); then
    cat "$work/gh-error" >&2
    give_up "GitHub shows no cache run for $tag after ${find_for}s."
  fi
  pause $((poll < 5 ? poll : 5))
done
echo "Waiting for CI to publish them: $url"

# One "<package>\t<state>" line per pending package. The job API doesn't
# show the plan's "packages" output, but the build matrix is that list:
# GitHub creates all of its jobs at once. So a package without a job wasn't
# planned once some "build <package>" job exists, or once the run succeeded.
# A run that ended any other way before building it failed for it.
# shellcheck disable=SC2016 # jq variables
states='
  (.jobs | map(select(.name == "plan")) | first) as $plan
  | (.jobs | any(.name | startswith("build ") and (contains("${{") | not))) as $expanded
  | .status as $run
  | .conclusion as $conclusion
  | .jobs as $jobs
  | $ARGS.positional[]
  | . as $pkg
  | ($jobs | map(select(.name == "build " + $pkg)) | first) as $job
  | [$pkg,
     if $job then
       if $job.status != "completed" then $job.status
       elif $job.conclusion == "success" then "published"
       else "failed: its job ended " + $job.conclusion end
     elif $plan.status == "completed" and $plan.conclusion != "success" then
       "failed: the plan ended " + $plan.conclusion
     elif $expanded or ($run == "completed" and $conclusion == "success") then "cached"
     elif $run == "completed" then "failed: the run ended " + ($conclusion // "early") + " before building it"
     elif $plan.status == "completed" then "plan done"
     else "plan " + ($plan.status // "queued") end]
  | @tsv'

deadline=$((SECONDS + timeout))
shown="" error=""
while :; do
  if view=$(gh run view "$run_id" --repo "$DEPLOY_GITHUB_REPO" --json status,conclusion,jobs \
    2>"$work/gh-error") &&
    report=$(jq -r "$states" --args "${pending[@]}" <<<"$view" 2>"$work/jq-error"); then
    still=() failed=() waiting=""
    while IFS=$'\t' read -r pkg state; do
      case $state in
      published) echo "CI published $pkg." ;;
      cached) echo "$pkg was in the cache by the time CI planned." ;;
      failed:*) failed+=("$pkg (${state#failed: })") ;;
      *)
        still+=("$pkg")
        waiting+="$pkg: $state, "
        ;;
      esac
    done <<<"$report"
    if ((${#failed[@]})); then
      give_up "CI didn't publish ${failed[*]}. $url"
    fi
    if ((${#still[@]} == 0)); then
      echo "CI has published everything this build needs."
      exit 0
    fi
    pending=("${still[@]}")
    waiting=${waiting%, }
    if [[ $waiting != "$shown" ]]; then
      echo "Waiting on ${waiting}."
      if [[ $waiting == *": waiting"* ]]; then
        echo "A waiting job needs its cache-publish deployment approved on GitHub."
      fi
      shown=$waiting
    fi
  elif ((!interrupted)); then
    last_error=$error
    error=$(cat "$work/gh-error" "$work/jq-error" 2>/dev/null || true)
    if [[ $error != "$last_error" ]]; then
      echo "deploy-wait: can't read the run yet: $error" >&2
    fi
  fi
  if ((interrupted)); then
    give_up ""
  fi
  if ((SECONDS >= deadline)); then
    if ((timeout >= 120)); then
      give_up "CI hasn't published ${pending[*]} after $((timeout / 60)) minutes. $url"
    fi
    give_up "CI hasn't published ${pending[*]} after ${timeout}s. $url"
  fi
  pause "$poll"
done
