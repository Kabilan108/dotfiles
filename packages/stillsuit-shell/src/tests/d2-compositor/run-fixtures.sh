#!/usr/bin/env bash
set -euo pipefail

fixture_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$fixture_dir/../.." && pwd)
tmp_dir=$(mktemp -d -t stillsuit-d2.XXXXXXXX)
shell_pid=""

cleanup() {
  if [[ -n $shell_pid ]] && kill -0 "$shell_pid" 2>/dev/null; then
    kill -TERM "$shell_pid"
    wait "$shell_pid" || true
  fi
  rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

export HOME="$tmp_dir/home"
export XDG_CONFIG_HOME="$tmp_dir/config"
export XDG_DATA_HOME="$tmp_dir/data"
export XDG_STATE_HOME="$tmp_dir/state"
export XDG_CACHE_HOME="$tmp_dir/cache"
export XDG_RUNTIME_DIR="$tmp_dir/runtime"
export QT_QPA_PLATFORM=offscreen
export STILLSUIT_D2_FIXTURE_STATE="$tmp_dir/fake-niri"
export PATH="$fixture_dir/fixtures:$PATH"
unset DBUS_SESSION_BUS_ADDRESS
mkdir -p "$HOME" "$XDG_CONFIG_HOME/quickshell" "$XDG_DATA_HOME" \
  "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR" "$STILLSUIT_D2_FIXTURE_STATE"
chmod 700 "$XDG_RUNTIME_DIR"
chmod +x "$fixture_dir/fixtures/niri"

config_id=stillsuit-d2-compositor-fixture
config_dir="$XDG_CONFIG_HOME/quickshell/$config_id"
mkdir -p "$config_dir"
ln -s "$fixture_dir/fixture-shell.qml" "$config_dir/shell.qml"
ln -s "$source_root/services" "$config_dir/services"
ln -s "$source_root/plugins" "$config_dir/plugins"
ln -s "$source_root/tests/FixtureTheme.js" "$config_dir/FixtureTheme.js"

ipc() {
  local reply
  for _ in {1..40}; do
    reply=$(qs ipc --pid "$shell_pid" call stillsuit-d2-compositor-fixture "$@") || return
    if [[ $reply != 'Not ready to accept queries yet.' ]]; then
      printf '%s\n' "$reply"
      return 0
    fi
    sleep 0.05
  done
  printf '%s\n' "$reply"
}
argv_count() { grep -cxF -- "$1" "$STILLSUIT_D2_FIXTURE_STATE/argv.log" || true; }

wait_for() {
  local expression state
  expression=$1
  for _ in {1..160}; do
    state=$(ipc state 2>/dev/null || true)
    if [[ -n $state ]] && jq -e "$expression" >/dev/null 2>&1 <<<"$state"; then
      printf '%s\n' "$state"
      return 0
    fi
    sleep 0.05
  done
  printf 'fixture condition timed out: %s\n' "$expression" >&2
  ipc state >&2 || true
  return 1
}

wait_for_reconciliation() {
  local expression reconciliation
  expression=$1
  for _ in {1..160}; do
    reconciliation=$(ipc reconciliation 2>/dev/null || true)
    if [[ -n $reconciliation ]] && jq -e "$expression" >/dev/null 2>&1 <<<"$reconciliation"; then
      printf '%s\n' "$reconciliation"
      return 0
    fi
    sleep 0.05
  done
  printf 'fixture reconciliation timed out: %s\n' "$expression" >&2
  ipc reconciliation >&2 || true
  return 1
}

wait_for_reconnect() {
  local expression reconnect
  expression=$1
  for _ in {1..160}; do
    reconnect=$(ipc reconnect 2>/dev/null || true)
    if [[ -n $reconnect ]] && jq -e "$expression" >/dev/null 2>&1 <<<"$reconnect"; then
      printf '%s\n' "$reconnect"
      return 0
    fi
    sleep 0.05
  done
  printf 'fixture reconnect timed out: %s\n' "$expression" >&2
  ipc reconnect >&2 || true
  return 1
}

qs --no-color -p "$config_dir" >"$tmp_dir/quickshell.log" 2>&1 &
shell_pid=$!
sleep 0.02
if ! kill -0 "$shell_pid" 2>/dev/null; then
  cat "$tmp_dir/quickshell.log" >&2
  wait "$shell_pid" || true
  exit 1
fi

wait_for_reconciliation '.completedGeneration >= 1 and .acceptedGeneration == 1' >/dev/null
first=$(wait_for '(.apiVersion == "1") and (.name == "niri") and (.focusedOutputId == "DP-2")')
jq -e '
  (.revision >= 1)
  and ((.outputs | type) == "array")
  and ([.outputs[].name] == ["DP-2", "eDP-1"])
  and (.outputs[0].id == "desk-output")
  and (.outputs[0].name == "DP-2")
  and (.outputs[1].id == "eDP-1")
  and (.outputs[1].name == "eDP-1")
  and ([.workspaces[].id] == [1])
  and ([.windows[].id] == [10])
' >/dev/null <<<"$first"

wait_for_reconciliation '.completedGeneration == 2 and .acceptedGeneration == 1 and .running == false' >/dev/null
after_bad=$(ipc state)
jq -e '
  ([.outputs[].name] == ["DP-2", "eDP-1"])
  and ([.workspaces[].id] == [1])
  and ([.windows[].id] == [10])
  and ([.windows[].title] == ["generation-1"])
  and ([.outputs[].name] | index("BROKEN-OUTPUT") == null)
' >/dev/null <<<"$after_bad"

jq -e '.intervalMs >= 60000' >/dev/null <<<"$(ipc reconciliation)"
[[ $(ipc inject '{"ConfigLoaded":{"failed":false}}') == false ]]
[[ $(ipc inject '{"KeyboardLayoutSwitched":{"idx":1}}') == false ]]
idle_outputs=$(argv_count 'msg -j outputs')
sleep 3
[[ $(argv_count 'msg -j outputs') -eq $idle_outputs ]]
[[ $(argv_count 'msg -j workspaces') -eq $idle_outputs ]]
[[ $(argv_count 'msg -j windows') -eq $idle_outputs ]]
jq -e '.completedGeneration == 2' >/dev/null <<<"$(ipc reconciliation)"

: >"$STILLSUIT_D2_FIXTURE_STATE/allow-malformed"
ipc reconcile >/dev/null
wait_for_reconciliation '.completedGeneration == 3 and .acceptedGeneration == 1 and .running == false' >/dev/null
after_malformed=$(ipc state)
jq -e '
  ([.outputs[].name] == ["DP-2", "eDP-1"])
  and ([.workspaces[].id] == [1])
  and ([.windows[].id] == [10])
  and ([.windows[].title] == ["generation-1"])
' >/dev/null <<<"$after_malformed"

: >"$STILLSUIT_D2_FIXTURE_STATE/allow-recovery"
ipc reconcile >/dev/null
wait_for_reconciliation '.completedGeneration == 4 and .acceptedGeneration == 1 and .timedOutGeneration == 4' >/dev/null
after_timeout=$(ipc state)
jq -e '
  ([.outputs[].name] == ["DP-2", "eDP-1"])
  and ([.workspaces[].id] == [1])
  and ([.windows[].id] == [10])
  and ([.windows[].title] == ["generation-1"])
' >/dev/null <<<"$after_timeout"

ipc reconcile >/dev/null
wait_for_reconciliation '.running == true' >/dev/null
ipc inject '{"WindowsChanged":{"windows":[{"id":40,"workspace_id":4,"title":"stream-newer","is_focused":true,"is_floating":false,"is_urgent":false,"layout":{"pos_in_scrolling_layout":[1,1],"tile_size":[640,480],"window_size":[640,480],"window_offset_in_tile":[0,0]}}]}}' >/dev/null
: >"$STILLSUIT_D2_FIXTURE_STATE/allow-final-recovery"
wait_for_reconciliation '.completedGeneration == 5 and .acceptedGeneration == 5 and .timedOutGeneration == 4' >/dev/null
recovered=$(wait_for '
  ([.outputs[].name] == ["HDMI-A-1"])
  and ([.workspaces[].id] == [4])
  and ([.windows[].id] == [40])
  and (.focusedOutputId == "HDMI-A-1")
')
jq -e '
  (.outputs[0].id == "HDMI-A-1")
  and (.outputs[0].make == "Recovered")
  and (.windows[0].title == "stream-newer")
' >/dev/null <<<"$recovered"

ipc inject '{"WorkspacesChanged":{"workspaces":[{"id":4,"idx":1,"output":"HDMI-A-1","is_active":true,"is_focused":true,"active_window_id":40,"is_urgent":false},{"id":5,"idx":2,"output":"HDMI-A-1","is_active":false,"is_focused":false,"is_urgent":false}]}}' >/dev/null
ipc inject '{"WindowsChanged":{"windows":[{"id":40,"workspace_id":4,"title":"stream-newer","is_focused":true,"layout":{"pos_in_scrolling_layout":[1,1],"tile_size":[640,480],"window_size":[640,480],"window_offset_in_tile":[0,0]},"is_floating":false,"is_urgent":false},{"id":41,"workspace_id":4,"title":"second","is_focused":false,"layout":{"pos_in_scrolling_layout":[2,1],"tile_size":[640,480],"window_size":[640,480],"window_offset_in_tile":[0,0]},"is_floating":false,"is_urgent":false}]}}' >/dev/null
ipc markRows >/dev/null
jq -e '.delegateStates == [{"id":4,"active":true},{"id":5,"active":false}] and .columns == 2 and .focusedColumn == 1' \
  >/dev/null <<<"$(ipc rowIdentity)"

ipc inject '{"WindowLayoutsChanged":{"changes":[[41,{"pos_in_scrolling_layout":[3,1],"tile_size":[640,480],"window_size":[640,480],"window_offset_in_tile":[0,0]}]]}}' >/dev/null
jq -e '
  .revisionDelta == 1 and .workspacesArraySame and (.windowsArraySame | not)
  and .windowRowsReused == {"40":true,"41":false}
  and .delegatesSame and .columns == 3
' >/dev/null <<<"$(ipc rowIdentity)"

ipc markRows >/dev/null
ipc inject '{"WorkspaceActiveWindowChanged":{"workspace_id":4,"active_window_id":41}}' >/dev/null
jq -e '
  .revisionDelta == 1 and .windowsArraySame
  and .workspaceRowsReused == {"4":false,"5":true}
  and .delegatesSame
' >/dev/null <<<"$(ipc rowIdentity)"

ipc markRows >/dev/null
[[ $(ipc inject '{"WindowFocusChanged":{"id":40}}') == false ]]
[[ $(ipc inject '{"WorkspacesChanged":{"workspaces":[{"id":4,"idx":1,"output":"HDMI-A-1","is_active":true,"is_focused":true,"active_window_id":41,"is_urgent":false},{"id":5,"idx":2,"output":"HDMI-A-1","is_active":false,"is_focused":false,"is_urgent":false}]}}') == false ]]
jq -e '.revisionDelta == 0 and .workspacesArraySame and .windowsArraySame' >/dev/null <<<"$(ipc rowIdentity)"

ipc inject '{"WorkspaceActivated":{"id":5,"focused":true}}' >/dev/null
jq -e '
  .revisionDelta == 1 and .windowsArraySame and .delegatesSame
  and .delegateStates == [{"id":4,"active":false},{"id":5,"active":true}]
' >/dev/null <<<"$(ipc rowIdentity)"
activated=$(ipc state)
jq -e '
  ([.workspaces[] | {id, is_active, is_focused}] == [{"id":4,"is_active":false,"is_focused":false},{"id":5,"is_active":true,"is_focused":true}])
  and (.focusedOutputId == "HDMI-A-1")
  and ([.windows[] | .layout.pos_in_scrolling_layout[0]] == [1,3])
' >/dev/null <<<"$activated"

ipc markRows >/dev/null
ipc inject '{"WindowOpenedOrChanged":{"window":{"id":42,"workspace_id":4,"title":"third","is_focused":true,"layout":{"pos_in_scrolling_layout":[4,1],"tile_size":[640,480],"window_size":[640,480],"window_offset_in_tile":[0,0]},"is_floating":false,"is_urgent":false}}}' >/dev/null
jq -e '.revisionDelta == 1 and .workspacesArraySame and .windowRowsReused == {"40":false,"41":true,"42":false}' \
  >/dev/null <<<"$(ipc rowIdentity)"
jq -e '[.windows[] | select(.is_focused) | .id] == [42]' >/dev/null <<<"$(ipc state)"
ipc inject '{"WindowOpenedOrChanged":{"window":{"id":40,"workspace_id":4,"title":"stream-newer","is_focused":true,"layout":{"pos_in_scrolling_layout":[1,1],"tile_size":[640,480],"window_size":[640,480],"window_offset_in_tile":[0,0]},"is_floating":false,"is_urgent":false}}}' >/dev/null
jq -e '[.windows[] | select(.is_focused) | .id] == [40]' >/dev/null <<<"$(ipc state)"
ipc inject '{"WindowOpenedOrChanged":{"window":{"id":41,"workspace_id":4,"title":"renamed","is_focused":false,"layout":{"pos_in_scrolling_layout":[3,1],"tile_size":[640,480],"window_size":[640,480],"window_offset_in_tile":[0,0]},"is_floating":false,"is_urgent":false}}}' >/dev/null
jq -e '[.windows[] | select(.is_focused) | .id] == [40] and ([.windows[].id] == [40,41,42])' >/dev/null <<<"$(ipc state)"

ipc inject '{"WindowUrgencyChanged":{"id":41,"urgent":true}}' >/dev/null
ipc inject '{"WorkspaceUrgencyChanged":{"id":4,"urgent":true}}' >/dev/null
ipc inject '{"WindowFocusTimestampChanged":{"id":40,"focus_timestamp":{"secs":5,"nanos":7}}}' >/dev/null
ipc inject '{"WindowFocusChanged":{"id":null}}' >/dev/null
jq -e '
  ([.windows[] | select(.is_urgent) | .id] == [41])
  and ([.workspaces[] | select(.is_urgent) | .id] == [4])
  and (.windows[0].focus_timestamp == {"secs":5,"nanos":7})
  and ([.windows[] | select(.is_focused)] == [])
' >/dev/null <<<"$(ipc state)"

jq -e '.lastFocusedWindowId == 40' >/dev/null <<<"$(ipc state)"
ipc inject '{"WindowClosed":{"id":42}}' >/dev/null
jq -e '.lastFocusedWindowId == 40 and ([.windows[].id] == [40,41])' >/dev/null <<<"$(ipc state)"
ipc inject '{"WindowClosed":{"id":40}}' >/dev/null
jq -e '.lastFocusedWindowId == null and ([.windows[].id] == [41])' >/dev/null <<<"$(ipc state)"
ipc inject '{"WindowFocusChanged":{"id":41}}' >/dev/null
ipc inject '{"WindowFocusChanged":{"id":null}}' >/dev/null
jq -e '.lastFocusedWindowId == 41 and ([.windows[] | select(.is_focused)] == [])' >/dev/null <<<"$(ipc state)"

ipc inject '{"WorkspacesChanged":{"workspaces":[{"id":4,"idx":1,"output":"HDMI-A-1","is_active":false,"is_focused":false,"active_window_id":41,"is_urgent":false},{"id":5,"idx":2,"output":"HDMI-A-1","is_active":true,"is_focused":true,"is_urgent":false},{"id":6,"idx":3,"output":"HDMI-A-1","is_active":false,"is_focused":false,"is_urgent":false}]}}' >/dev/null
ipc markRows >/dev/null
jq -e '.delegateStates == [{"id":4,"active":false},{"id":5,"active":true},{"id":6,"active":false}]' >/dev/null <<<"$(ipc rowIdentity)"
ipc inject '{"WorkspacesChanged":{"workspaces":[{"id":4,"idx":1,"output":"HDMI-A-1","is_active":true,"is_focused":true,"active_window_id":41,"is_urgent":false},{"id":6,"idx":2,"output":"HDMI-A-1","is_active":false,"is_focused":false,"is_urgent":false}]}}' >/dev/null
jq -e '
  .revisionDelta == 1
  and .delegateKept == {"4":true,"6":true}
  and .delegateStates == [{"id":4,"active":true},{"id":6,"active":false}]
' >/dev/null <<<"$(ipc rowIdentity)"

wait_for_argv_count() {
  local argv expected
  argv=$1
  expected=$2
  for _ in {1..160}; do
    if [[ $(argv_count "$argv") -eq $expected ]]; then return 0; fi
    sleep 0.05
  done
  printf 'argv %q did not reach count %s\n' "$argv" "$expected" >&2
  cat "$STILLSUIT_D2_FIXTURE_STATE/argv.log" >&2
  return 1
}
[[ $(ipc focusWorkspace 6) == ok ]]
wait_for_argv_count 'msg action focus-workspace 2' 1
[[ $(ipc focusWorkspace 4) == ok ]]
[[ $(ipc focusWorkspace 999) == unknown-workspace ]]
[[ $(ipc focusWorkspace abc) == invalid-workspace ]]
[[ $(ipc focusWorkspace 0) == invalid-workspace ]]
sleep 0.3
[[ $(argv_count 'msg action focus-workspace 1') -eq 0 ]]
[[ $(argv_count 'msg action focus-workspace 2') -eq 1 ]]
ipc inject '{"WorkspacesChanged":{"workspaces":[{"id":4,"idx":1,"output":"HDMI-A-1","is_active":true,"is_focused":true,"active_window_id":41,"is_urgent":false},{"id":6,"idx":2,"output":"HDMI-A-1","is_active":false,"is_focused":false,"is_urgent":false},{"id":7,"idx":1,"output":"DP-9","is_active":false,"is_focused":false,"is_urgent":false}]}}' >/dev/null
[[ $(ipc focusWorkspace 7) == ok ]]
wait_for_argv_count 'msg action focus-monitor DP-9' 1
wait_for_argv_count 'msg action focus-workspace 1' 1
monitor_line=$(grep -nxF -- 'msg action focus-monitor DP-9' "$STILLSUIT_D2_FIXTURE_STATE/argv.log" | cut -d: -f1)
workspace_line=$(grep -nxF -- 'msg action focus-workspace 1' "$STILLSUIT_D2_FIXTURE_STATE/argv.log" | cut -d: -f1)
(( monitor_line < workspace_line ))
[[ $(argv_count 'msg action focus-window --id 0') -eq 0 ]]

: >"$STILLSUIT_D2_FIXTURE_STATE/hold-reconcile"
before_invalid=$(ipc state)
for invalid in \
  '{"WindowsChanged":{"windows":[null]}}' \
  '{"WindowsChanged":{"windows":[{"id":"40","title":"string-id"}]}}' \
  '{"WindowsChanged":{"windows":[{"id":40},{"id":40}]}}' \
  '{"WorkspacesChanged":{"workspaces":[{"id":4,"is_active":"yes"}]}}' \
  '{"WindowOpenedOrChanged":{"window":{"title":"no-id"}}}' \
  '{"WorkspaceActivated":{"id":999,"focused":true}}' \
  '{"WorkspaceActiveWindowChanged":{"workspace_id":4,"active_window_id":"41"}}' \
  '{"WindowClosed":{"id":999}}' \
  '{"WindowFocusChanged":{"id":"40"}}' \
  '{"WindowLayoutsChanged":{"changes":[[41,null]]}}' \
  '{"WindowUrgencyChanged":{"id":41}}' \
  '{"WindowFocusChanged":{"id":999}}' \
  '{"WindowFocusChanged":{}}' \
  '{"WindowsChanged":{"windows":[{"id":22}]}}' \
  '{"WindowOpenedOrChanged":{"window":{"id":43,"is_focused":false,"is_floating":false,"is_urgent":false,"layout":{"pos_in_scrolling_layout":[1,1]}}}}' \
  '{"WindowLayoutsChanged":{"changes":[[41,{"pos_in_scrolling_layout":[2,1]}]]}}' \
  '{"WorkspacesChanged":{"workspaces":[{"id":4,"idx":1,"is_active":true,"is_focused":true}]}}' \
  '{"WindowUrgencyChanged":{"id":999,"urgent":true}}' \
  '{"WorkspaceUrgencyChanged":{"id":999,"urgent":true}}' \
  '{"WindowFocusTimestampChanged":{"id":999,"focus_timestamp":null}}' \
  '{"WindowFocusTimestampChanged":{"id":40,"focus_timestamp":{"secs":"5"}}}' \
  '{"SomeFutureEvent":{}}'; do
  [[ $(ipc inject "$invalid") == false ]]
done
[[ $(ipc state) == "$before_invalid" ]]
wait_for_reconciliation '.completedGeneration == 5 and .running == true' >/dev/null
rm -f -- "$STILLSUIT_D2_FIXTURE_STATE/hold-reconcile"
wait_for_reconciliation '.completedGeneration == 7 and .acceptedGeneration == 7 and .running == false' >/dev/null

: >"$STILLSUIT_D2_FIXTURE_STATE/release-stream"
wait_for_reconciliation '.completedGeneration >= 8 and .acceptedGeneration >= 8' >/dev/null
[[ $(<"$STILLSUIT_D2_FIXTURE_STATE/stream-count") -ge 2 ]]

reconnect=$(wait_for_reconnect '.attempts >= 4 and .scheduledDelayMs == 200')
jq -e '.baseDelayMs == 50 and .doubledDelayMs == 100 and .cappedDelayMs == 200' >/dev/null <<<"$reconnect"
[[ $(<"$STILLSUIT_D2_FIXTURE_STATE/stream-count") -ge 4 ]]

ownership=$(ipc ownership)
jq -e '.serviceInstances == 1 and .adapterInstances == 1' >/dev/null <<<"$ownership"
LC_ALL=C sort -u "$STILLSUIT_D2_FIXTURE_STATE/argv.log" >"$tmp_dir/argv.unique"
diff -u <(printf '%s\n' 'msg --json event-stream' 'msg -j outputs' 'msg -j windows' 'msg -j workspaces' \
  'msg action focus-monitor DP-9' 'msg action focus-workspace 1' 'msg action focus-workspace 2') "$tmp_dir/argv.unique"

if rg --line-number --ignore-case '(binding loop|typeerror|referenceerror)' "$tmp_dir/quickshell.log" >"$tmp_dir/quickshell-errors"; then
  cat "$tmp_dir/quickshell-errors" >&2
  exit 1
else
  rg_status=$?
  if (( rg_status != 1 )); then exit "$rg_status"; fi
fi
