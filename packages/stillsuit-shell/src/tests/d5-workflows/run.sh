#!/usr/bin/env bash
set -euo pipefail

fixture_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package_dir=$(cd -- "$fixture_dir/../../.." && pwd)
tmp_dir=$(mktemp -d -t stillsuit-d5.XXXXXXXX)
shell_pid=""
socket_pid=""
fake_recorder_pid=""
helper_recorder_pid=""

cleanup() {
  local status=$?
  if [[ -n $shell_pid ]] && kill -0 "$shell_pid" 2>/dev/null; then kill "$shell_pid"; wait "$shell_pid" 2>/dev/null || true; fi
  if [[ -n $socket_pid ]] && kill -0 "$socket_pid" 2>/dev/null; then kill "$socket_pid"; wait "$socket_pid" 2>/dev/null || true; fi
  if [[ -n $fake_recorder_pid ]] && kill -0 "$fake_recorder_pid" 2>/dev/null; then kill "$fake_recorder_pid"; wait "$fake_recorder_pid" 2>/dev/null || true; fi
  if [[ -n $helper_recorder_pid ]] && kill -0 "$helper_recorder_pid" 2>/dev/null; then kill "$helper_recorder_pid"; fi
  if [[ -z ${STILLSUIT_FIXTURE_KEEP:-} ]]; then rm -rf -- "$tmp_dir"; else printf 'fixture retained: %s\n' "$tmp_dir" >&2; fi
  exit "$status"
}
trap cleanup EXIT

export HOME="$tmp_dir/home"
export XDG_CONFIG_HOME="$tmp_dir/config"
export XDG_DATA_HOME="$tmp_dir/data"
export XDG_CACHE_HOME="$tmp_dir/cache"
export XDG_STATE_HOME="$tmp_dir/state"
export XDG_RUNTIME_DIR="$tmp_dir/runtime"
export STILLSUIT_FIXTURE_HELPER="$fixture_dir/fake-recorder"
export STILLSUIT_FIXTURE_HELPER_LOG="$tmp_dir/helper.log"
export STILLSUIT_FIXTURE_RECORDING_STATE="$tmp_dir/recording.json"
export STILLSUIT_FIXTURE_MEETING_STATE="$tmp_dir/meeting.json"
export STILLSUIT_FIXTURE_MEETING_JOBS="$tmp_dir/jobs.json"
export STILLSUIT_FIXTURE_MEETING_HELPER="$fixture_dir/fake-meeting-control"
export STILLSUIT_FIXTURE_MEETING_CONTROL_LOG="$tmp_dir/meeting-control.log"
export STILLSUIT_FIXTURE_OPEN_HELPER="$fixture_dir/fake-open"
export STILLSUIT_FIXTURE_OPEN_LOG="$tmp_dir/open.log"
export STILLSUIT_FIXTURE_SOCKET="$tmp_dir/dictator.sock"
export STILLSUIT_FIXTURE_MEETING_LOG="$tmp_dir/meeting-helper.log"
# This fixture exercises services only; force the isolated renderer rather than
# attaching an overlay test to the live compositor.
export QT_QPA_PLATFORM=offscreen
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

for variable_name in HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME XDG_RUNTIME_DIR; do
  [[ ${!variable_name} == "$tmp_dir"/* ]] || { echo "fixture escaped temporary roots: $variable_name" >&2; exit 1; }
done

fixture_started_at=$(($(date +%s) - 4))
printf '{"schemaVersion":1,"phase":"recording","pid":1,"monitor":"DP-1","started_at":%s,"paused_at":0,"paused_total":0,"elapsed_seconds":4}\n' "$fixture_started_at" > "$STILLSUIT_FIXTURE_RECORDING_STATE"
printf '%s\n' '{"schemaVersion":1,"phase":"completed","label":"fixture","note_path":"/tmp/fixture-note.md","visible_until":4102444800}' > "$STILLSUIT_FIXTURE_MEETING_STATE"
jq -n '{schemaVersion:1, jobs:[
  {job_id:("a"*32),phase:"queued",title:"Queued newest",label:"Minutes queued",attempt:1,updated_at:700,created_at:700},
  {job_id:("b"*32),phase:"transcribing",title:"Processing",label:"Transcribing meeting",progress:62,total:100,attempt:1,updated_at:600,created_at:600},
  {job_id:("c"*32),phase:"error",title:"Failed C",label:"Meeting failed",error:"Siren failed\nfull diagnostic C",attempt:1,updated_at:500,created_at:500},
  {job_id:("d"*32),phase:"error",title:"Failed D",label:"Meeting failed",error:"failure D",attempt:2,updated_at:400,created_at:400},
  {job_id:("e"*32),phase:"error",title:"Failed E",label:"Meeting failed",error:"failure E",attempt:1,updated_at:300,created_at:300},
  {job_id:("f"*32),phase:"error",title:"Failed F",label:"Meeting failed",error:"failure F",attempt:1,updated_at:200,created_at:200},
  {job_id:("0"*32),phase:"error",title:"Failed G",label:"Meeting failed",error:"failure G",attempt:1,updated_at:100,created_at:100},
  {job_id:("1"*32),phase:"completed",title:"Completed newest",label:"Meeting note ready",note_path:"/tmp/completed-1.md",attempt:1,updated_at:900,completed_at:900,created_at:50},
  {job_id:("2"*32),phase:"completed",title:"Completed older",label:"Meeting note ready",note_path:"/tmp/completed-2.md",attempt:1,updated_at:800,completed_at:800,created_at:40},
  {job_id:("3"*32),phase:"completed",title:"Completed oldest",label:"Meeting note ready",note_path:"/tmp/completed-3.md",attempt:1,updated_at:700,completed_at:700,created_at:30}
]}' > "$STILLSUIT_FIXTURE_MEETING_JOBS"
python3 "$fixture_dir/socket-server.py" "$STILLSUIT_FIXTURE_SOCKET" >"$tmp_dir/socket.log" 2>&1 &
socket_pid=$!
for _ in {1..100}; do [[ -S $STILLSUIT_FIXTURE_SOCKET ]] && break; sleep 0.02; done
[[ -S $STILLSUIT_FIXTURE_SOCKET ]]

config_dir="$tmp_dir/quickshell"
mkdir -p "$config_dir/plugins/builtin" "$config_dir/services"
cp "$fixture_dir/WorkflowFixture.qml" "$config_dir/shell.qml"
cp -R "$package_dir/src/services/." "$config_dir/services/"
cp -R "$package_dir/src/plugins/builtin/workflows" "$config_dir/plugins/builtin/workflows"
cp -R "$package_dir/src/plugins/builtin/osd" "$config_dir/plugins/builtin/osd"
cp -R "$package_dir/src/plugins/builtin/recording" "$config_dir/plugins/builtin/recording"
cp -R "$package_dir/src/plugins/builtin/meeting" "$config_dir/plugins/builtin/meeting"

ipc() { qs ipc --pid "$shell_pid" call stillsuit-d5-fixture "$@"; }
wait_json() {
  local expression=$1 state
  for _ in {1..160}; do
    state=$(ipc state 2>/dev/null || true)
    if [[ -n $state ]] && jq -e "$expression" >/dev/null 2>&1 <<<"$state"; then printf '%s\n' "$state"; return 0; fi
    sleep 0.05
  done
  echo "fixture condition timed out: $expression" >&2
  ipc state >&2 || true
  return 1
}
start_shell() {
  qs --no-color -p "$config_dir" >"$tmp_dir/quickshell.log" 2>&1 &
  shell_pid=$!
  wait_json '.aggregateApiVersion == "1" and .dictator.socketConnections == 1' >/dev/null
}
stop_shell() {
  local pid=$shell_pid
  kill "$pid"
  wait "$pid" 2>/dev/null || true
  shell_pid=""
}

start_shell
wait_json '.recording.status == "ready" and .meeting.jobsStatus == "ready"' >/dev/null
state=$(ipc state)
jq -e '.serviceObjects == 1 and .osdServiceObjects == 1 and .overlays == 2 and .overlaySharesAggregate and .overlaySharesOsdService and .dictator.levels == 23 and .dictator.state == "recording" and .meeting.visible and .meeting.completed and .meeting.label == "fixture"' >/dev/null <<<"$state"

# The queue ranks all actionable phases before completed results and caps every
# page at five rows. Ties remain deterministic through job identity.
jq -e '.queue.page == 0 and .queue.pageCount == 2 and .queue.actionableCount == 7
  and .queue.olderActionableCount == 2 and (.queue.jobs | length) == 5
  and [.queue.jobs[].phase] == ["queued","transcribing","error","error","error"]' >/dev/null <<<"$state"
[[ $(ipc nextPage) == ok ]]
state=$(ipc state)
jq -e '.queue.page == 1 and (.queue.jobs | length) == 5
  and [.queue.jobs[].phase] == ["error","error","completed","completed","completed"]' >/dev/null <<<"$state"
[[ $(ipc previousPage) == ok ]]

# Completed history fills spare actionable slots but never creates a history-
# only overflow page; with no actionable jobs it is a newest-first five-row view.
jq -e '.completedOnlyQueue.page == 0 and .completedOnlyQueue.pageCount == 1
  and .completedOnlyQueue.actionableCount == 0 and (.completedOnlyQueue.hasNextPage | not)
  and [.completedOnlyQueue.jobs[].jobId] == ["completed-6","completed-5","completed-4","completed-3","completed-2"]' \
  >/dev/null <<<"$state"

# Completion closes after exactly five seconds of unpaused ticks. Pointer or
# focus interaction uses the same model flag and preserves the remaining time.
[[ $(ipc completionStart) == ok ]]
[[ $(ipc completionTick 2000) == waiting ]]
[[ $(ipc completionInteract true) == ok ]]
[[ $(ipc completionTick 5000) == waiting ]]
jq -e '.completion.remainingMs == 3000 and .completion.interactionActive and .completion.expirationCount == 0' >/dev/null <<<"$(ipc state)"
[[ $(ipc completionInteract false) == ok ]]
[[ $(ipc completionTick 2999) == waiting ]]
[[ $(ipc completionTick 1) == expired ]]
jq -e '.completion.remainingMs == 0 and (.completion.running | not) and .completion.expirationCount == 1' >/dev/null <<<"$(ipc state)"

# The global service derives elapsed time once per second from the recorder's
# timestamps. No helper rewrite is needed, and a current pause stays excluded.
first_elapsed=$(jq -r '.recording.elapsedSeconds' <<<"$state")
sleep 1.2
second_elapsed=$(jq -r '.recording.elapsedSeconds' <<<"$(ipc state)")
(( second_elapsed >= first_elapsed + 1 ))

pause_now=$(date +%s)
pause_started=$((pause_now - 20))
pause_at=$((pause_now - 5))
printf '{"schemaVersion":1,"phase":"paused","pid":1,"monitor":"DP-1","started_at":%s,"paused_at":%s,"paused_total":3,"elapsed_seconds":12}\n' "$pause_started" "$pause_at" > "$STILLSUIT_FIXTURE_RECORDING_STATE"
[[ $(ipc refresh) == ok ]]
paused_state=$(wait_json '.recording.paused and .recording.status == "ready"')
paused_elapsed=$(jq -r '.recording.elapsedSeconds' <<<"$paused_state")
[[ $paused_elapsed == 12 ]]
sleep 1.2
[[ $(jq -r '.recording.elapsedSeconds' <<<"$(ipc state)") == "$paused_elapsed" ]]

# Quickshell 0.3 FileView watches the target's parent directory even when the
# target was missing at startup. External creation must load without an IPC
# refresh or a helper action.
stop_shell
rm -- "$STILLSUIT_FIXTURE_RECORDING_STATE"
start_shell
wait_json '.recording.status == "missing" and .recording.phase == "idle"' >/dev/null
printf '{"schemaVersion":1,"phase":"recording","pid":1,"monitor":"DP-1","started_at":%s}\n' "$(date +%s)" > "$STILLSUIT_FIXTURE_RECORDING_STATE"
wait_json '.recording.status == "ready" and .recording.phase == "recording"' >/dev/null

# Drive the real recorder helper through start and stop --meeting using only
# temporary fake process and enqueue executables. Feed its emitted version-1
# state directly into the production RecordingService parser.
mkdir -p "$HOME/bin" "$tmp_dir/actual-recordings"
cp "$fixture_dir/fake-meeting-minutes" "$HOME/bin/meeting-minutes"
recorder_helper="$package_dir/../../bin/stillsuit-recorder"
PATH="$fixture_dir:$PATH" "$recorder_helper" start \
  --directory "$tmp_dir/actual-recordings" --monitor DP-1 --title fixture-meeting \
  --desktop-audio --no-microphone > "$tmp_dir/recorder-start.json"
helper_recorder_pid=$(jq -r '.pid' "$tmp_dir/recorder-start.json")
PATH="$fixture_dir:$PATH" "$recorder_helper" stop --meeting > "$tmp_dir/recorder-meeting.json"
helper_recorder_pid=""
jq -e '.schemaVersion == 1 and .phase == "meeting_queued" and .meeting_job_id == "fixture-job"' "$tmp_dir/recorder-meeting.json" >/dev/null
cp "$tmp_dir/recorder-meeting.json" "$STILLSUIT_FIXTURE_RECORDING_STATE"
[[ $(ipc refresh) == ok ]]
wait_json '.recording.status == "ready" and .recording.phase == "meeting_queued" and .recording.completed and (.recording.outputFilename | endswith("fixture-meeting.mp4"))' >/dev/null
meeting_recording=$(jq -r '.output' "$tmp_dir/recorder-meeting.json")
[[ $(<"$STILLSUIT_FIXTURE_MEETING_LOG") == "enqueue --recording $meeting_recording --started-at "*" --duration-seconds "* ]]

# The action uses only literal argv; the fake helper sees the exact reviewed order.
[[ $(ipc start) == started ]]
for _ in {1..100}; do [[ -s $STILLSUIT_FIXTURE_HELPER_LOG ]] && break; sleep 0.02; done
[[ $(<"$STILLSUIT_FIXTURE_HELPER_LOG") == 'start --directory /tmp/fixture-recordings --monitor DP-1 --title fixture-title --desktop-audio --no-microphone' ]]

# The zero-argument D4 contract uses only reviewed configured defaults.
[[ $(ipc d4Start) == started ]]
for _ in {1..100}; do [[ $(wc -l < "$STILLSUIT_FIXTURE_HELPER_LOG") -eq 2 ]] && break; sleep 0.02; done
[[ $(sed -n '2p' "$STILLSUIT_FIXTURE_HELPER_LOG") == 'start --directory /tmp/fixture-recordings --monitor DP-1 --title fixture-default-title --desktop-audio --no-microphone' ]]
[[ $(ipc d4Finish) == started ]]
for _ in {1..100}; do [[ $(wc -l < "$STILLSUIT_FIXTURE_HELPER_LOG") -eq 3 ]] && break; sleep 0.02; done
[[ $(sed -n '3p' "$STILLSUIT_FIXTURE_HELPER_LOG") == 'stop' ]]

# Every active transport action maps to one fixed argv and waits for the prior
# dispatch to finish. No panel-local process owns the recorder.
printf '{"schemaVersion":1,"phase":"recording","pid":1,"monitor":"DP-1","started_at":%s,"output":"/tmp/fixture-recordings/active.mp4"}\n' "$(date +%s)" > "$STILLSUIT_FIXTURE_RECORDING_STATE"
[[ $(ipc refresh) == ok ]]
wait_json '.recording.active' >/dev/null
[[ $(ipc pause) == started ]]
for _ in {1..100}; do [[ $(wc -l < "$STILLSUIT_FIXTURE_HELPER_LOG") -eq 4 ]] && break; sleep 0.02; done
[[ $(sed -n '4p' "$STILLSUIT_FIXTURE_HELPER_LOG") == 'toggle-pause' ]]
[[ $(ipc finishMeeting) == started ]]
for _ in {1..100}; do [[ $(wc -l < "$STILLSUIT_FIXTURE_HELPER_LOG") -eq 5 ]] && break; sleep 0.02; done
[[ $(sed -n '5p' "$STILLSUIT_FIXTURE_HELPER_LOG") == 'stop --meeting' ]]
[[ $(ipc d4Finish) == started ]]
for _ in {1..100}; do [[ $(wc -l < "$STILLSUIT_FIXTURE_HELPER_LOG") -eq 6 ]] && break; sleep 0.02; done
[[ $(sed -n '6p' "$STILLSUIT_FIXTURE_HELPER_LOG") == 'stop' ]]
[[ $(ipc cancel) == started ]]
for _ in {1..100}; do [[ $(wc -l < "$STILLSUIT_FIXTURE_HELPER_LOG") -eq 7 ]] && break; sleep 0.02; done
[[ $(sed -n '7p' "$STILLSUIT_FIXTURE_HELPER_LOG") == 'cancel' ]]

# Rename output is applied from the helper response before copy/open actions.
# The copied path therefore follows the successful rename.
printf '%s\n' '{"schemaVersion":1,"phase":"completed","output":"/tmp/fixture-recordings/original.mp4","title":"original","elapsed_seconds":62,"size_bytes":2048}' > "$STILLSUIT_FIXTURE_RECORDING_STATE"
[[ $(ipc refresh) == ok ]]
wait_json '.recording.completed and .recording.outputFilename == "original.mp4"' >/dev/null
[[ $(ipc rename 'renamed fixture') == started ]]
wait_json '.recording.outputFilename == "renamed fixture.mp4" and (.recording.actionRunning | not)' >/dev/null
[[ $(ipc copyPath) == copied ]]
jq -e '.recording.copiedPath == "/tmp/fixture-recordings/renamed fixture.mp4"' >/dev/null <<<"$(ipc state)"
[[ $(ipc openRecording) == started ]]
for _ in {1..100}; do [[ -s $STILLSUIT_FIXTURE_OPEN_LOG ]] && break; sleep 0.02; done
[[ $(sed -n '1p' "$STILLSUIT_FIXTURE_OPEN_LOG") == '/tmp/fixture-recordings/renamed fixture.mp4' ]]
[[ $(ipc openFolder) == started ]]
for _ in {1..100}; do [[ $(wc -l < "$STILLSUIT_FIXTURE_OPEN_LOG") -eq 2 ]] && break; sleep 0.02; done
[[ $(sed -n '2p' "$STILLSUIT_FIXTURE_OPEN_LOG") == '/tmp/fixture-recordings' ]]

[[ $(ipc openResult) == started ]]
for _ in {1..100}; do [[ $(wc -l < "$STILLSUIT_FIXTURE_OPEN_LOG") -eq 3 ]] && break; sleep 0.02; done
[[ $(sed -n '3p' "$STILLSUIT_FIXTURE_OPEN_LOG") == '/tmp/fixture-note.md' ]]

# Retry is manual, reuses the same identity, increments attempt, and rejects a
# second dispatch while the first is pending.
retry_id=$(printf 'c%.0s' {1..32})
[[ $(ipc doubleRetry "$retry_id") == '["started","unavailable"]' ]]
wait_json ".meeting.jobs[] | select(.jobId == \"$retry_id\" and .phase == \"queued\" and .attempt == 2)" >/dev/null
[[ $(grep -c "^retry $retry_id$" "$STILLSUIT_FIXTURE_MEETING_CONTROL_LOG") -eq 1 ]]

# As older failures resolve, completed results move into the current five-row
# page. One failure remains inspectable and is not retried by refresh/reload.
temporary_jobs="$STILLSUIT_FIXTURE_MEETING_JOBS.tmp"
jq '(.jobs[] | select(.job_id == ("d"*32) or .job_id == ("e"*32) or .job_id == ("f"*32))).phase = "completed"
  | (.jobs[] | select(.phase == "completed" and .note_path == null)).note_path = "/tmp/resolved.md"' \
  "$STILLSUIT_FIXTURE_MEETING_JOBS" > "$temporary_jobs"
mv -- "$temporary_jobs" "$STILLSUIT_FIXTURE_MEETING_JOBS"
wait_json '.queue.page == 0 and .queue.actionableCount == 4 and (.queue.jobs | length) == 5
  and [.queue.jobs[].phase] == ["queued","queued","transcribing","error","completed"]' >/dev/null
[[ $(grep -c "^retry " "$STILLSUIT_FIXTURE_MEETING_CONTROL_LOG") -eq 1 ]]

printf '%s\n' '{"schemaVersion":1,"phase":"error","label":"fixture failed","error":"fixture error","visible_until":4102444800}' > "$STILLSUIT_FIXTURE_MEETING_STATE"
[[ $(ipc refresh) == ok ]]
wait_json '.meeting.failed and .meeting.visible and .meeting.label == "fixture failed" and .meeting.errorMessage == "fixture error"' >/dev/null

# The previous meeting-minutes writer emitted this exact field family without
# schemaVersion. The read-only service migrates it in memory until the producer
# replaces the durable file on its next update.
printf '%s\n' '{"job_id":"legacy-job","phase":"completed","label":"legacy fixture","progress":1,"total":1,"note_path":"/tmp/legacy-note.md","error":"","updated_at":1788134400,"visible_until":4102444800}' > "$STILLSUIT_FIXTURE_MEETING_STATE"
[[ $(ipc refresh) == ok ]]
wait_json '.meeting.status == "migrated" and .meeting.completed and .meeting.label == "legacy fixture" and .meeting.snapshotSchemaVersion == 1' >/dev/null
printf '%s\n' '{"phase":"completed"}' > "$STILLSUIT_FIXTURE_MEETING_STATE"
[[ $(ipc refresh) == ok ]]
wait_json '.meeting.status == "unsupported" and .meeting.phase == "idle"' >/dev/null

# Corrupt and future-version durable state are contained without commanding the helper.
printf '%s\n' '{broken' > "$STILLSUIT_FIXTURE_RECORDING_STATE"
[[ $(ipc refresh) == ok ]]
wait_json '.recording.status == "corrupt" and .recording.phase == "idle"' >/dev/null
printf '%s\n' '{"schemaVersion":2,"phase":"recording"}' > "$STILLSUIT_FIXTURE_MEETING_STATE"
[[ $(ipc refresh) == ok ]]
wait_json '.meeting.status == "unsupported" and .meeting.phase == "idle"' >/dev/null

# A live-looking recorder is external authority. Destroy/recreate the fixture
# and prove it neither invokes stop nor signals this private fake process.
sleep 60 &
fake_recorder_pid=$!
printf '{"schemaVersion":1,"phase":"recording","pid":%s,"monitor":"DP-1"}\n' "$fake_recorder_pid" > "$STILLSUIT_FIXTURE_RECORDING_STATE"
[[ $(ipc refresh) == ok ]]
wait_json '.recording.active and .recording.status == "ready"' >/dev/null
stop_shell
kill -0 "$fake_recorder_pid"
retry_count_before_reload=$(grep -c '^retry ' "$STILLSUIT_FIXTURE_MEETING_CONTROL_LOG")
start_shell
kill -0 "$fake_recorder_pid"
[[ $(grep -c '^retry ' "$STILLSUIT_FIXTURE_MEETING_CONTROL_LOG") -eq "$retry_count_before_reload" ]]

# Presentational per-output files may not own workflow authority.
if rg -n '(^|[^[:alnum:]_])(Timer|FileView|PwObjectTracker|Socket|Process|IpcHandler)[[:space:]]*\{' "$package_dir/src/plugins/builtin/osd/OsdOverlay.qml" "$package_dir/src/plugins/builtin/osd/DictationPill.qml"; then
  echo "presentational OSD files own workflow authority" >&2
  exit 1
fi
rg -n 'function onScanPosChanged\(\) \{ root\.repaint\(\) \}' "$package_dir/src/plugins/builtin/osd/DictationPill.qml" >/dev/null
rg -n 'running: root\.visible && \(root\.completed \|\| root\.failed\)' "$package_dir/src/services/MeetingService.qml" >/dev/null
if rg -n 'ERROR:|Failed to load configuration|Type .* unavailable' "$tmp_dir/quickshell.log"; then
  echo "fixture log contains a QML load error" >&2
  exit 1
fi

echo "d5-workflows: ok"
