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

qs --no-color -p "$config_dir" > "$tmp_dir/quickshell.log" 2>&1 &
shell_pid=$!
ipc() { qs ipc --pid "$shell_pid" call stillsuit-recording-meetings-fixture "$@"; }
for _ in {1..120}; do [[ $(ipc ready 2>/dev/null || true) == ready ]] && break; sleep 0.05; done
[[ $(ipc ready) == ready ]]

# Starting, pausing, resuming, and cancelling are terminal panel interactions.
# The accepted command closes the panel before its resulting phase is rendered.
[[ $(ipc startFromPanel) == started ]]
jq -e '.recordingPhase == "recording" and .recordingOpen == false' \
  <<< "$(ipc state)" >/dev/null
[[ $(ipc togglePauseFromPanel recording) == started ]]
jq -e '.recordingPhase == "paused" and .recordingOpen == false' \
  <<< "$(ipc state)" >/dev/null
[[ $(ipc togglePauseFromPanel paused) == started ]]
jq -e '.recordingPhase == "recording" and .recordingOpen == false' \
  <<< "$(ipc state)" >/dev/null
[[ $(ipc cancelFromPanel) == started ]]
jq -e '.recordingPhase == "idle" and .recordingOpen == false' \
  <<< "$(ipc state)" >/dev/null

[[ $(ipc openRecording idle) == open ]]
[[ $(ipc openRecording recording) == open ]]
state=$(ipc state)
jq -e '.recordingPanelWidth < .standardPanelWidth' <<< "$state" >/dev/null
[[ $(ipc openRecording completed) == open ]]
jq -e '.recordingOpen and .recordingMeetingRows == 1 and .meetingRows == 2' \
  <<< "$(ipc state)" >/dev/null
[[ $(ipc renameFromPanel 'renamed fixture') == started ]]
jq -e '.renameTitle == "renamed fixture"' <<< "$(ipc state)" >/dev/null
[[ $(ipc closeCompletedPanel) == closed ]]
jq -e '.recordingPhase == "idle" and .recordingOpen == false
  and .dismissCount == 1' <<< "$(ipc state)" >/dev/null

# Completion actions close immediately. Opening a file or folder defers the
# state dismissal until its asynchronous launcher exits; copying dismisses now.
[[ $(ipc openFileFromPanel) == started ]]
jq -e '.recordingPhase == "completed" and .recordingOpen == false
  and .actionRunning and .openRecordingCount == 1' <<< "$(ipc state)" >/dev/null
[[ $(ipc finishOpenAction) == finished ]]
jq -e '.recordingPhase == "idle" and .dismissCount == 2' \
  <<< "$(ipc state)" >/dev/null
[[ $(ipc openFolderFromPanel) == started ]]
jq -e '.recordingPhase == "completed" and .recordingOpen == false
  and .actionRunning and .openFolderCount == 1' <<< "$(ipc state)" >/dev/null
[[ $(ipc finishOpenAction) == finished ]]
jq -e '.recordingPhase == "idle" and .dismissCount == 3' \
  <<< "$(ipc state)" >/dev/null
[[ $(ipc copyPathFromPanel) == copied ]]
jq -e '.recordingPhase == "idle" and .recordingOpen == false
  and .copyPathCount == 1 and .copiedPath == "/tmp/recordings/renamed fixture.mp4"
  and .dismissCount == 4' <<< "$(ipc state)" >/dev/null

# Reduced motion no longer changes the static recording icon.
[[ $(ipc setReducedMotion true) == ok ]]
state=$(ipc state)
jq -e '.recordingWidgetIcon == "record"
  and .recordingWidgetOutputLabel == "eDP-1"
  and .recordingWidgetWidth < .standardPanelWidth' <<< "$state" >/dev/null
[[ $(ipc setReducedMotion false) == ok ]]
jq -e '.recordingWidgetIcon == "record"' <<< "$(ipc state)" >/dev/null

# A single click toggles pause after the double-click window. A double click
# cancels that pending toggle and opens the recording panel instead.
[[ $(ipc resetInteractionCounts) == ok ]]
[[ $(ipc singleClickRecordingWidget) == queued ]]
sleep 0.4
state=$(ipc state)
jq -e '.togglePauseCount == 1 and .surfaceToggleCount == 0
  and .recordingWidgetIcon == "pause"' <<< "$state" >/dev/null
[[ $(ipc doubleClickRecordingWidget) == opened ]]
sleep 0.4
state=$(ipc state)
jq -e '.togglePauseCount == 1 and .surfaceToggleCount == 1
  and .lastOpenPlugin == "stillsuit.recording"' <<< "$state" >/dev/null

# Discarding the failed job removes it permanently and leaves the unrelated
# completed job untouched.
[[ $(ipc discardJob aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa) == ok ]]
state=$(ipc state)
jq -e '.recordingMeetingRows == 0 and .meetingRows == 1' <<< "$state" >/dev/null

# A subsequent reload of the durable job state must not resurrect the
# discarded job.
[[ $(ipc refreshMeeting) == ok ]]
state=$(ipc state)
jq -e '.recordingMeetingRows == 0 and .meetingRows == 1' <<< "$state" >/dev/null

if rg -n 'ERROR:|Failed to load configuration|Type .* unavailable|Cannot assign to non-existent property' "$tmp_dir/quickshell.log"; then
  echo "recording-meetings fixture logged a QML error" >&2
  exit 1
fi

rg -n 'FailedMeetingJobsView|Finish as meeting|Pause|Resume|Finish|Cancel|Copy path' "$source_root/plugins/builtin/recording/RecordingPanel.qml" >/dev/null
if rg -n 'Recent meetings|Open in Obsidian|Previous|Next' \
  "$source_root/plugins/builtin/recording/RecordingPanel.qml" \
  "$source_root/plugins/builtin/recording/FailedMeetingJobsView.qml"; then
  echo "recording panel exposes meeting history instead of failed-job recovery" >&2
  exit 1
fi
rg -n 'Failed meeting jobs|Details|Retry|Discard' "$source_root/plugins/builtin/recording/FailedMeetingJobsView.qml" >/dev/null
echo "recording-meetings panels: ok"
