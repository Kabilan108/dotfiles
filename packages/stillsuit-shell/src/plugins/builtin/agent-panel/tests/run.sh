#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=$(mktemp -d)
readonly TEST_DIR
HELPER=${HELPER:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)/bin/stillsuit-agent-panel}
readonly HELPER
PLUGIN_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly PLUGIN_ROOT
readonly REAL_PATH=$PATH
REAL_TMUX=$(command -v tmux)
readonly REAL_TMUX
readonly FIXTURE_TMUX_SOCKET="$TEST_DIR/tmux.sock"

cleanup() {
  if [[ -r $TEST_DIR/fixture/innocent.pid ]]; then
    kill "$(<"$TEST_DIR/fixture/innocent.pid")" 2>/dev/null || true
  fi
  if [[ -r $TEST_DIR/fixture/ghostty.pids ]]; then
    local pid
    while IFS= read -r pid; do
      if [[ $pid =~ ^[1-9][0-9]*$ ]]; then kill "$pid" 2>/dev/null || true; fi
    done <"$TEST_DIR/fixture/ghostty.pids"
  fi
  "$REAL_TMUX" -S "$FIXTURE_TMUX_SOCKET" kill-server 2>/dev/null || true
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

jq -e '
  .kinds == ["service"] and
  .entryPoints == {"service": "AgentPanelService.qml"} and
  .scope == {"service": "global"} and
  (has("barWidget") | not)
' "$PLUGIN_ROOT/manifest.json" >/dev/null ||
  fail "agent-panel manifest is not service-only"
[[ ! -e $PLUGIN_ROOT/AgentPanelWidget.qml ]] ||
  fail "agent-panel bar widget source still exists"

cat >"$TEST_DIR/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
require_exact_target() {
  [[ ${2:-} == -t && ${3:-} == =stillsuit-agent ]] || {
    printf 'non-exact tmux target: %q\n' "$*" >&2
    exit 97
  }
}
case ${1:-} in
  has-session)
    require_exact_target "$@"
    [[ -e $FIXTURE_ROOT/session ]]
    ;;
  list-panes)
    require_exact_target "$@"
    [[ -e $FIXTURE_ROOT/session ]] || exit 1
    if [[ -e $FIXTURE_ROOT/dead ]]; then printf '1\n'; else printf '0\n'; fi
    ;;
  new-session)
    [[ ${2:-} == -d && ${3:-} == -s && ${4:-} == stillsuit-agent ]] || exit 97
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
  set-option)
    require_exact_target "$@"
    printf '%s\n' "$*" >>"$FIXTURE_ROOT/tmux-options"
    ;;
  kill-session)
    require_exact_target "$@"
    rm -f "$FIXTURE_ROOT/session" "$FIXTURE_ROOT/dead"
    ;;
  attach-session)
    require_exact_target "$@"
    ;;
  *) exit 2 ;;
esac
EOF

cat >"$TEST_DIR/bin/niri" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == msg && ${2:-} == -j && ${3:-} == windows ]]; then
  count=0
  [[ -r $FIXTURE_ROOT/window-query-count ]] && count=$(<"$FIXTURE_ROOT/window-query-count")
  printf '%s\n' "$((count + 1))" >"$FIXTURE_ROOT/window-query-count"
  if [[ -s $FIXTURE_ROOT/window-opening-polls ]]; then
    polls=$(<"$FIXTURE_ROOT/window-opening-polls")
    if ((polls <= 1)); then
      printf '41\n' >"$FIXTURE_ROOT/window"
      rm -f "$FIXTURE_ROOT/window-opening-polls"
    else
      printf '%s\n' "$((polls - 1))" >"$FIXTURE_ROOT/window-opening-polls"
    fi
  fi
  if [[ -s $FIXTURE_ROOT/window-closing-polls ]]; then
    polls=$(<"$FIXTURE_ROOT/window-closing-polls")
    if ((polls <= 1)); then
      rm -f "$FIXTURE_ROOT/window" "$FIXTURE_ROOT/window-closing-polls"
    else
      printf '%s\n' "$((polls - 1))" >"$FIXTURE_ROOT/window-closing-polls"
    fi
  fi
  if [[ -s $FIXTURE_ROOT/window ]]; then
    id=$(<"$FIXTURE_ROOT/window")
    printf '[{"id":%s,"app_id":"com.mitchellh.ghostty","title":"Stillsuit Agent"},{"id":90,"app_id":"com.mitchellh.ghostty","title":"Ordinary terminal"},{"id":91,"app_id":"other","title":"Stillsuit Agent"}]\n' "$id"
  else
    printf '[]\n'
  fi
elif [[ ${1:-} == msg && ${2:-} == action && ${3:-} == close-window ]]; then
  if [[ -s $FIXTURE_ROOT/close-delay-polls ]]; then
    cp "$FIXTURE_ROOT/close-delay-polls" "$FIXTURE_ROOT/window-closing-polls"
  else
    rm -f "$FIXTURE_ROOT/window"
  fi
elif [[ ${1:-} == msg && ${2:-} == action && ${3:-} == focus-window ]]; then
  :
else
  exit 2
fi
EOF

cat >"$TEST_DIR/bin/ghostty" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 3 && $1 == +new-window && $2 == "--title=Stillsuit Agent"
   && $3 == "--command=direct:tmux attach-session -t =stillsuit-agent" ]] || exit 97
printf '%s\n' "$@" >"$FIXTURE_ROOT/ghostty.argv"
count=0
[[ -r $FIXTURE_ROOT/new-window-count ]] && count=$(<"$FIXTURE_ROOT/new-window-count")
printf '%s\n' "$((count + 1))" >"$FIXTURE_ROOT/new-window-count"
if [[ -e $FIXTURE_ROOT/window ]]; then touch "$FIXTURE_ROOT/window-overlap"; fi
if [[ -s $FIXTURE_ROOT/open-delay-polls ]]; then
  cp "$FIXTURE_ROOT/open-delay-polls" "$FIXTURE_ROOT/window-opening-polls"
else
  printf '41\n' >"$FIXTURE_ROOT/window"
fi
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
      if [[ $pid =~ ^[1-9][0-9]*$ ]]; then
        kill "$pid" 2>/dev/null || true
        for _ in $(seq 1 100); do
          kill -0 "$pid" 2>/dev/null || break
          sleep 0.01
        done
      fi
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
mapfile -t ghostty_argv <"$FIXTURE_ROOT/ghostty.argv"
assert_eq "+new-window" "${ghostty_argv[0]}" "shared Ghostty request"
grep -Fx 'set-option -t =stillsuit-agent set-titles off' "$FIXTURE_ROOT/tmux-options" >/dev/null ||
  fail "agent session did not disable title rewriting"
assert_eq 1 "$("$HELPER" status | jq -r .windowCount)" "window identity rejects title and app-ID near misses"
[[ " ${ghostty_argv[*]} " == *" --command=direct:tmux attach-session -t =stillsuit-agent "* ]] ||
  fail "Ghostty did not receive an exact direct tmux attach target"
assert_eq false "$("$HELPER" status | jq -r .launchPending)" "settled launch status"

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
printf '4\n' >"$FIXTURE_ROOT/close-delay-polls"
"$HELPER" open >/dev/null
[[ -e $FIXTURE_ROOT/session ]] || fail "stale window did not create a session"
assert_eq 41 "$(<"$FIXTURE_ROOT/window")" "stale window replacement"
[[ ! -e $FIXTURE_ROOT/window-overlap ]] || fail "new Ghostty overlapped a closing window"

reset_fixture
touch "$FIXTURE_ROOT/session" "$FIXTURE_ROOT/dead"
printf '74\n' >"$FIXTURE_ROOT/window"
"$HELPER" open >/dev/null
[[ ! -e $FIXTURE_ROOT/dead ]] || fail "dead Codex session was not replaced"
assert_eq 41 "$(<"$FIXTURE_ROOT/window")" "dead Codex window replacement"

reset_fixture
touch "$FIXTURE_ROOT/session"
"$HELPER" open >/dev/null
"$HELPER" hide >/dev/null
assert_eq absent "$("$HELPER" status | jq -r .window)" "hidden shared window status"
printf '4\n' >"$FIXTURE_ROOT/open-delay-polls"
"$HELPER" open >/dev/null &
first_open_pid=$!
"$HELPER" open >/dev/null &
second_open_pid=$!
wait "$first_open_pid"
wait "$second_open_pid"
assert_eq 2 "$(<"$FIXTURE_ROOT/new-window-count")" "one initial and one concurrent reopen request"
[[ ! -e $FIXTURE_ROOT/window-overlap ]] || fail "concurrent reopen overlapped windows"

reset_fixture
sleep 60 &
innocent_pid=$!
printf '%s\n' "$innocent_pid" >"$FIXTURE_ROOT/innocent.pid"
printf '%s\n' "$innocent_pid" >"$XDG_RUNTIME_DIR/agent-panel-ghostty.pid"
"$HELPER" terminate >/dev/null
kill -0 "$innocent_pid" 2>/dev/null || fail "terminate signalled an unverified fixture process"
kill "$innocent_pid"
wait "$innocent_pid" 2>/dev/null || true
rm -f "$FIXTURE_ROOT/innocent.pid"

reset_fixture
toggle_pids=()
for _ in $(seq 1 24); do
  "$HELPER" toggle >/dev/null &
  toggle_pids+=("$!")
done
for toggle_pid in "${toggle_pids[@]}"; do
  wait "$toggle_pid"
done
[[ -e $FIXTURE_ROOT/session ]] || fail "toggle storm lost the persistent session"
assert_eq 1 "$(<"$FIXTURE_ROOT/session-count")" "single session after storm"
window_count=0
[[ -e $FIXTURE_ROOT/window ]] && window_count=1
((window_count <= 1)) || fail "toggle storm created duplicate windows"
"$HELPER" open >/dev/null
assert_eq 1 "$(jq -r .windowCount < <("$HELPER" status))" "single window after storm"

"$HELPER" terminate >/dev/null
assert_eq absent "$("$HELPER" status | jq -r .session)" "fixture termination"

reset_fixture
mkdir -p "$TEST_DIR/real-bin"
ln -s "$TEST_DIR/bin/niri" "$TEST_DIR/real-bin/niri"
cat >"$TEST_DIR/real-bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$REAL_TMUX" -S "$FIXTURE_TMUX_SOCKET" "$@"
EOF
chmod +x "$TEST_DIR/real-bin/tmux"
export REAL_TMUX FIXTURE_TMUX_SOCKET
export PATH="$TEST_DIR/real-bin:$REAL_PATH"
"$REAL_TMUX" -S "$FIXTURE_TMUX_SOCKET" new-session -d -s stillsuit-agent-extra sleep 60
assert_eq absent "$("$HELPER" status | jq -r .session)" "real tmux prefix decoy ignored"
"$REAL_TMUX" -S "$FIXTURE_TMUX_SOCKET" new-session -d -s stillsuit-agent sleep 60
assert_eq running "$("$HELPER" status | jq -r .session)" "real tmux exact session found"
"$HELPER" terminate >/dev/null
"$REAL_TMUX" -S "$FIXTURE_TMUX_SOCKET" has-session -t =stillsuit-agent-extra ||
  fail "terminate killed the prefixed real tmux decoy"

printf 'agent-panel fixtures: ok\n'
