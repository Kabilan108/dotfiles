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
    printf '[{"id":%s,"app_id":"io.stillsuit.AgentPanel"}]\n' "$id"
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

if [[ ${1:-} == +new-window ]]; then
  [[ " $* " == *" --class=io.stillsuit.AgentPanel "* ]] || exit 2
  [[ " $* " == *" --title=Stillsuit Agent "* ]] || exit 2
  [[ -r $FIXTURE_ROOT/active-ghostty.pid ]] || exit 3
  persistent_pid=$(<"$FIXTURE_ROOT/active-ghostty.pid")
  kill -0 "$persistent_pid" 2>/dev/null || exit 3
  printf '%s\n' "$@" >"$FIXTURE_ROOT/new-window.argv"
  count=0
  [[ -r $FIXTURE_ROOT/new-window-count ]] && count=$(<"$FIXTURE_ROOT/new-window-count")
  printf '%s\n' "$((count + 1))" >"$FIXTURE_ROOT/new-window-count"
  if [[ -e $FIXTURE_ROOT/window ]]; then
    touch "$FIXTURE_ROOT/window-overlap"
  fi
  if [[ -s $FIXTURE_ROOT/open-delay-polls ]]; then
    cp "$FIXTURE_ROOT/open-delay-polls" "$FIXTURE_ROOT/window-opening-polls"
  else
    printf '41\n' >"$FIXTURE_ROOT/window"
  fi
  exit 0
fi

[[ " $* " == *" --class=io.stillsuit.AgentPanel "* ]] || exit 2
printf '%s\n' "$@" >"$FIXTURE_ROOT/ghostty.argv"
printf '%s\n' "$BASHPID" >>"$FIXTURE_ROOT/ghostty.pids"
count=0
[[ -r $FIXTURE_ROOT/ghostty-launch-count ]] && count=$(<"$FIXTURE_ROOT/ghostty-launch-count")
printf '%s\n' "$((count + 1))" >"$FIXTURE_ROOT/ghostty-launch-count"
if [[ -r $FIXTURE_ROOT/active-ghostty.pid ]]; then
  previous_pid=$(<"$FIXTURE_ROOT/active-ghostty.pid")
  if kill -0 "$previous_pid" 2>/dev/null; then
    touch "$FIXTURE_ROOT/ghostty-overlap"
  fi
fi
printf '%s\n' "$BASHPID" >"$FIXTURE_ROOT/active-ghostty.pid"
if [[ -e $FIXTURE_ROOT/window ]]; then
  touch "$FIXTURE_ROOT/window-overlap"
fi
printf '41\n' >"$FIXTURE_ROOT/window"
cleanup_ghostty() {
  active_pid=''
  [[ -r $FIXTURE_ROOT/active-ghostty.pid ]] && active_pid=$(<"$FIXTURE_ROOT/active-ghostty.pid")
  if [[ $active_pid == "$BASHPID" ]]; then
    rm -f "$FIXTURE_ROOT/active-ghostty.pid" "$FIXTURE_ROOT/window"
  fi
}
stop_ghostty() {
  touch "$FIXTURE_ROOT/term-requested"
  if [[ -s $FIXTURE_ROOT/term-delay ]]; then
    sleep "$(<"$FIXTURE_ROOT/term-delay")"
  fi
  exit 0
}
trap cleanup_ghostty EXIT
trap stop_ghostty TERM INT
while :; do sleep 0.05; done
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
[[ " ${ghostty_argv[*]} " == *" --gtk-single-instance=true "* ]] ||
  fail "Ghostty was not launched as a custom single instance"
[[ " ${ghostty_argv[*]} " == *" --quit-after-last-window-closed=false "* ]] ||
  fail "Ghostty was not configured to survive a hidden surface"
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
old_pid=$(<"$XDG_RUNTIME_DIR/agent-panel-ghostty.pid")
"$HELPER" hide >/dev/null
kill -0 "$old_pid" 2>/dev/null || fail "hide terminated the persistent Ghostty"
assert_eq absent "$("$HELPER" status | jq -r .window)" "hidden persistent window status"
assert_eq false "$("$HELPER" status | jq -r .launchPending)" "hidden persistent launch status"
printf '4\n' >"$FIXTURE_ROOT/open-delay-polls"
"$HELPER" open >/dev/null &
first_open_pid=$!
"$HELPER" open >/dev/null &
second_open_pid=$!
wait "$first_open_pid"
wait "$second_open_pid"
assert_eq "$old_pid" "$(<"$XDG_RUNTIME_DIR/agent-panel-ghostty.pid")" "reopen persistent Ghostty PID"
assert_eq 1 "$(<"$FIXTURE_ROOT/ghostty-launch-count")" "single Ghostty process launch after reopen"
assert_eq 1 "$(<"$FIXTURE_ROOT/new-window-count")" "single remote window request during concurrent reopen"

reset_fixture
touch "$FIXTURE_ROOT/session"
"$HELPER" open >/dev/null
old_pid=$(<"$XDG_RUNTIME_DIR/agent-panel-ghostty.pid")
printf '0.25\n' >"$FIXTURE_ROOT/term-delay"
"$HELPER" terminate >/dev/null &
terminate_pid=$!
for _ in $(seq 1 100); do
  [[ -e $FIXTURE_ROOT/term-requested ]] && break
  sleep 0.01
done
[[ -e $FIXTURE_ROOT/term-requested ]] || fail "delayed Ghostty did not receive TERM"
"$HELPER" open >/dev/null
wait "$terminate_pid"
kill -0 "$old_pid" 2>/dev/null && fail "open returned before the old Ghostty exited"
[[ ! -e $FIXTURE_ROOT/ghostty-overlap ]] || fail "new Ghostty overlapped the exiting Ghostty"

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
assert_eq 1 "$(<"$FIXTURE_ROOT/ghostty-launch-count")" "single persistent Ghostty after storm"
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
