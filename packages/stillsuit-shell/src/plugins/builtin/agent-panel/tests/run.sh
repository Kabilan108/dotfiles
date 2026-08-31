#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(mktemp -d)
readonly TEST_DIR
HELPER=${HELPER:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)/bin/stillsuit-agent-panel}
readonly HELPER
readonly REAL_PATH=$PATH

cleanup() {
  if [[ -r $TEST_DIR/fixture/ghostty.pids ]]; then
    local pid
    while IFS= read -r pid; do
      if [[ $pid =~ ^[1-9][0-9]*$ ]]; then kill "$pid" 2>/dev/null || true; fi
    done <"$TEST_DIR/fixture/ghostty.pids"
  fi
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

mkdir -p "$TEST_DIR/bin" "$TEST_DIR/home" "$TEST_DIR/config/stillsuit" \
  "$TEST_DIR/state" "$TEST_DIR/runtime" "$TEST_DIR/fixture"

export HOME="$TEST_DIR/home"
export XDG_CONFIG_HOME="$TEST_DIR/config"
export XDG_STATE_HOME="$TEST_DIR/state"
export XDG_RUNTIME_DIR="$TEST_DIR/runtime"
export FIXTURE_ROOT="$TEST_DIR/fixture"
export PATH="$TEST_DIR/bin:$REAL_PATH"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local expected=$1 actual=$2 label=$3
  [[ $actual == "$expected" ]] || fail "$label: expected '$expected', got '$actual'"
}

cat >"$TEST_DIR/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case ${1:-} in
  has-session)
    [[ -e $FIXTURE_ROOT/session ]]
    ;;
  list-panes)
    [[ -e $FIXTURE_ROOT/session ]] || exit 1
    if [[ -e $FIXTURE_ROOT/dead ]]; then printf '1\n'; else printf '0\n'; fi
    ;;
  new-session)
    touch "$FIXTURE_ROOT/session"
    rm -f "$FIXTURE_ROOT/dead"
    count=0
    [[ -r $FIXTURE_ROOT/session-count ]] && count=$(<"$FIXTURE_ROOT/session-count")
    printf '%s\n' "$((count + 1))" >"$FIXTURE_ROOT/session-count"
    : >"$FIXTURE_ROOT/codex.argv"
    found=false
    for arg in "$@"; do
      if [[ $found == true ]]; then printf '%s\n' "$arg" >>"$FIXTURE_ROOT/codex.argv"; fi
      [[ $arg == -- ]] && found=true
    done
    exit 0
    ;;
  set-option) ;;
  kill-session)
    rm -f "$FIXTURE_ROOT/session" "$FIXTURE_ROOT/dead"
    ;;
  attach-session) ;;
  *) exit 2 ;;
esac
EOF

cat >"$TEST_DIR/bin/niri" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == msg && ${2:-} == -j && ${3:-} == windows ]]; then
  if [[ -s $FIXTURE_ROOT/window ]]; then
    id=$(<"$FIXTURE_ROOT/window")
    printf '[{"id":%s,"app_id":"io.stillsuit.AgentPanel"}]\n' "$id"
  else
    printf '[]\n'
  fi
elif [[ ${1:-} == msg && ${2:-} == action && ${3:-} == close-window ]]; then
  rm -f "$FIXTURE_ROOT/window"
elif [[ ${1:-} == msg && ${2:-} == action && ${3:-} == focus-window ]]; then
  :
else
  exit 2
fi
EOF

cat >"$TEST_DIR/bin/ghostty" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ " $* " == *" --class=io.stillsuit.AgentPanel "* ]] || exit 2
printf '%s\n' "$@" >"$FIXTURE_ROOT/ghostty.argv"
printf '%s\n' "$BASHPID" >>"$FIXTURE_ROOT/ghostty.pids"
printf '41\n' >"$FIXTURE_ROOT/window"
trap 'rm -f "$FIXTURE_ROOT/window"' EXIT
trap 'exit 0' TERM INT
while :; do sleep 1; done
EOF

cat >"$TEST_DIR/bin/codex" <<'EOF'
#!/usr/bin/env bash
exit 99
EOF

chmod +x "$TEST_DIR/bin/tmux" "$TEST_DIR/bin/niri" "$TEST_DIR/bin/ghostty" "$TEST_DIR/bin/codex"

reset_fixture() {
  if [[ -r $FIXTURE_ROOT/ghostty.pids ]]; then
    local pid
    while IFS= read -r pid; do
      if [[ $pid =~ ^[1-9][0-9]*$ ]]; then kill "$pid" 2>/dev/null || true; fi
    done <"$FIXTURE_ROOT/ghostty.pids"
  fi
  rm -f "$FIXTURE_ROOT"/* "$XDG_RUNTIME_DIR/agent-panel-ghostty.pid" \
    "$XDG_CONFIG_HOME/stillsuit/agent-panel.json"
}

reset_fixture
"$HELPER" open >/dev/null
assert_eq running "$("$HELPER" status | jq -r .session)" "absent session launch"
mapfile -t argv <"$FIXTURE_ROOT/codex.argv"
expected=(codex --yolo --model gpt-5.6-sol --config model_reasoning_effort=low --config service_tier=fast)
assert_eq "${expected[*]}" "${argv[*]}" "fixed default Codex argv"

if "$HELPER" open injected >/dev/null 2>&1; then
  fail "extra action argument was accepted"
fi

reset_fixture
cat >"$XDG_CONFIG_HOME/stillsuit/agent-panel.json" <<'EOF'
{"model":"gpt-5.6-sol;touch /tmp/pwned","reasoningEffort":"low","serviceTier":"fast","command":"sh"}
EOF
if "$HELPER" open >/dev/null 2>&1; then
  fail "hostile config was accepted"
fi
[[ ! -e $FIXTURE_ROOT/session ]] || fail "hostile config started a session"

reset_fixture
printf '73\n' >"$FIXTURE_ROOT/window"
"$HELPER" open >/dev/null
[[ -e $FIXTURE_ROOT/session ]] || fail "stale window did not create a session"
assert_eq 41 "$(<"$FIXTURE_ROOT/window")" "stale window replacement"

reset_fixture
touch "$FIXTURE_ROOT/session" "$FIXTURE_ROOT/dead"
printf '74\n' >"$FIXTURE_ROOT/window"
"$HELPER" open >/dev/null
[[ ! -e $FIXTURE_ROOT/dead ]] || fail "dead Codex session was not replaced"
assert_eq 41 "$(<"$FIXTURE_ROOT/window")" "dead Codex window replacement"

reset_fixture
for _ in $(seq 1 24); do
  "$HELPER" toggle >/dev/null &
done
wait
[[ -e $FIXTURE_ROOT/session ]] || fail "toggle storm lost the persistent session"
assert_eq 1 "$(<"$FIXTURE_ROOT/session-count")" "single session after storm"
window_count=0
[[ -e $FIXTURE_ROOT/window ]] && window_count=1
((window_count <= 1)) || fail "toggle storm created duplicate windows"
"$HELPER" open >/dev/null
assert_eq 1 "$(jq -r .windowCount < <("$HELPER" status))" "single window after storm"

"$HELPER" terminate >/dev/null
assert_eq absent "$("$HELPER" status | jq -r .session)" "fixture termination"

printf 'agent-panel fixtures: ok\n'
