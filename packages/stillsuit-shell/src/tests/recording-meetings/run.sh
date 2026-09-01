#!/usr/bin/env bash
set -euo pipefail

fixture_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$fixture_dir/../.." && pwd)
tmp_dir=$(mktemp -d -t stillsuit-recording-meetings.XXXXXXXX)
shell_pid=""
sway_pid=""

cleanup() {
  local status=$?
  if [[ -n $shell_pid ]] && kill -0 "$shell_pid" 2>/dev/null; then kill -TERM "$shell_pid"; wait "$shell_pid" 2>/dev/null || true; fi
  if [[ -n $sway_pid ]] && kill -0 "$sway_pid" 2>/dev/null; then kill -TERM "$sway_pid"; wait "$sway_pid" 2>/dev/null || true; fi
  if [[ -z ${STILLSUIT_FIXTURE_KEEP:-} ]]; then rm -rf -- "$tmp_dir"; else printf 'fixture retained: %s\n' "$tmp_dir" >&2; fi
  exit "$status"
}
trap cleanup EXIT

export HOME="$tmp_dir/home"
export XDG_CONFIG_HOME="$tmp_dir/config"
export XDG_DATA_HOME="$tmp_dir/data"
export XDG_STATE_HOME="$tmp_dir/state"
export XDG_CACHE_HOME="$tmp_dir/cache"
export XDG_RUNTIME_DIR="$tmp_dir/runtime"
export QT_QPA_PLATFORM=wayland
unset DBUS_SESSION_BUS_ADDRESS
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

sway_bin=$(command -v sway || true)
if [[ -z $sway_bin ]]; then sway_bin="$(nix build --no-link --print-out-paths nixpkgs#sway)/bin/sway"; fi
printf '%s\n' 'output * resolution 1280x720' > "$tmp_dir/sway.conf"
DBUS_SESSION_BUS_ADDRESS="unix:path=$tmp_dir/no-session-bus" \
  WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=1 WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman \
  "$sway_bin" -c "$tmp_dir/sway.conf" > "$tmp_dir/sway.log" 2>&1 &
sway_pid=$!
wayland_socket=""
for _ in {1..100}; do
  for candidate in "$XDG_RUNTIME_DIR"/wayland-*; do
    if [[ -S $candidate ]]; then wayland_socket=$candidate; break; fi
  done
  [[ -n $wayland_socket ]] && break
  sleep 0.02
done
[[ -n $wayland_socket ]] || { cat "$tmp_dir/sway.log" >&2; exit 1; }
export WAYLAND_DISPLAY=${wayland_socket##*/}

config_dir="$tmp_dir/quickshell"
mkdir -p "$config_dir/plugins/builtin"
cp "$fixture_dir/fixture-shell.qml" "$config_dir/shell.qml"
cp -R "$source_root/ui" "$config_dir/ui"
cp -R "$source_root/plugins/builtin/recording" "$config_dir/plugins/builtin/recording"
cp -R "$source_root/plugins/builtin/meeting" "$config_dir/plugins/builtin/meeting"

qs --no-color -p "$config_dir" > "$tmp_dir/quickshell.log" 2>&1 &
shell_pid=$!
ipc() { qs ipc --pid "$shell_pid" call stillsuit-recording-meetings-fixture "$@"; }
for _ in {1..120}; do [[ $(ipc ready 2>/dev/null || true) == ready ]] && break; sleep 0.05; done
[[ $(ipc ready) == ready ]]
[[ $(ipc openRecording idle) == open ]]
[[ $(ipc openRecording recording) == open ]]
[[ $(ipc openRecording completed) == open ]]
[[ $(ipc openMeetings) == ok ]]
jq -e '.recordingOpen and .selectedView == "meetings" and .recordingMeetingRows == 2
  and (.meetingOpen | not) and .meetingRows == 2
  and .meetingRoute == {pluginId:"stillsuit.recording",payload:"{\"view\":\"meetings\"}"}' \
  <<< "$(ipc state)" >/dev/null

# Both real recording indicators retain their static dot but expose no running
# pulse when the user requests reduced motion.
[[ $(ipc setReducedMotion true) == ok ]]
state=$(ipc state)
jq -e '.pulses.widget == false and .pulses.panel == false
  and .pulses.widgetScale == 1 and .pulses.panelScale == 1' <<< "$state" >/dev/null
[[ $(ipc setReducedMotion false) == ok ]]
jq -e '.pulses.widget and .pulses.panel' <<< "$(ipc state)" >/dev/null

if rg -n 'ERROR:|Failed to load configuration|Type .* unavailable|Cannot assign to non-existent property' "$tmp_dir/quickshell.log"; then
  echo "recording-meetings fixture logged a QML error" >&2
  exit 1
fi

rg -n 'Recent meetings|MeetingQueueView|Finish as meeting|Pause|Resume|Finish|Cancel|Copy path' "$source_root/plugins/builtin/recording/RecordingPanel.qml" >/dev/null
rg -n 'surfaceOpen\("stillsuit\.recording", "\{\\"view\\":\\"meetings\\"\}"\)' "$source_root/plugins/builtin/meeting/MeetingWidget.qml" >/dev/null
rg -n 'Details|Retry|Open in Obsidian' "$source_root/plugins/builtin/meeting/MeetingQueueView.qml" >/dev/null
echo "recording-meetings panels: ok"
