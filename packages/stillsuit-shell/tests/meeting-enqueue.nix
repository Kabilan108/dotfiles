{ pkgs }:
let
  fakeSystemctl = pkgs.writeShellScriptBin "systemctl" ''
    printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"
  '';
  helper = pkgs.callPackage ../meeting-enqueue-helper.nix {
    systemctlProvider = fakeSystemctl;
  };
in
pkgs.runCommand "stillsuit-meeting-enqueue-test"
  {
    nativeBuildInputs = [ pkgs.jq ];
  }
  ''
    set -euo pipefail

    state_dir="$TMPDIR/state"
    media_root="$TMPDIR/media"
    recording="$TMPDIR/recording.mp4"
    systemctl_log="$TMPDIR/systemctl.log"
    mkdir -p "$state_dir" "$media_root"
    printf 'temporary recording\n' > "$recording"

    result="$(${pkgs.coreutils}/bin/env -i \
      HOME="$TMPDIR/home" \
      PATH= \
      MEETING_MINUTES_STATE_DIR="$state_dir" \
      MEETING_MINUTES_MEDIA_ROOT="$media_root" \
      SYSTEMCTL_LOG="$systemctl_log" \
      ${pkgs.lib.getExe helper} enqueue \
        --recording "$recording" \
        --started-at 1234 \
        --duration-seconds 42)"

    jq -e '.phase == "queued" and .worker_started == true' <<< "$result" >/dev/null
    job_id="$(jq -er '.job_id | select(test("^[a-f0-9]{32}$"))' <<< "$result")"
    test "$(jq -r '.recording' <<< "$result")" = "$media_root/.inbox/$job_id.mp4"
    test -s "$media_root/.inbox/$job_id.mp4"
    test ! -e "$recording"
    jq -e \
      --arg job_id "$job_id" \
      --arg recording "$media_root/.inbox/$job_id.mp4" \
      '.job_id == $job_id and .phase == "queued" and .attempt == 1 and .recording_path == $recording' \
      "$state_dir/jobs/$job_id.json" >/dev/null
    jq -e \
      --arg job_id "$job_id" \
      '.schemaVersion == 1 and .actionable_count == 1 and .completed_limit == 20
        and (.jobs | length) == 1 and .jobs[0].job_id == $job_id
        and .jobs[0].phase == "queued" and .jobs[0].attempt == 1' \
      "$state_dir/jobs.json" >/dev/null
    test "$(<"$systemctl_log")" = \
      "--user start --no-block meeting-minutes-worker.service"

    # Failed jobs stay failed until an explicit retry. Retry keeps the identity,
    # increments attempt under the job lock, and dispatches the worker once.
    temporary_job="$state_dir/jobs/$job_id.tmp"
    jq '.phase = "error" | .error = "fixture failure"' \
      "$state_dir/jobs/$job_id.json" > "$temporary_job"
    mv -- "$temporary_job" "$state_dir/jobs/$job_id.json"
    ${pkgs.coreutils}/bin/env -i \
      HOME="$TMPDIR/home" \
      PATH= \
      MEETING_MINUTES_STATE_DIR="$state_dir" \
      MEETING_MINUTES_MEDIA_ROOT="$media_root" \
      SYSTEMCTL_LOG="$systemctl_log" \
      ${pkgs.lib.getExe helper} work
    jq -e '.phase == "error" and .attempt == 1 and .error == "fixture failure"' \
      "$state_dir/jobs/$job_id.json" >/dev/null
    test "$(wc -l < "$systemctl_log")" -eq 1

    retry_result="$(${pkgs.coreutils}/bin/env -i \
      HOME="$TMPDIR/home" \
      PATH= \
      MEETING_MINUTES_STATE_DIR="$state_dir" \
      MEETING_MINUTES_MEDIA_ROOT="$media_root" \
      SYSTEMCTL_LOG="$systemctl_log" \
      ${pkgs.lib.getExe helper} retry "$job_id")"
    jq -e --arg job_id "$job_id" \
      '.job_id == $job_id and .phase == "queued" and .attempt == 2 and .error == ""' \
      <<< "$retry_result" >/dev/null
    test "$(wc -l < "$systemctl_log")" -eq 2
    test "$(sed -n '2p' "$systemctl_log")" = \
      "--user start --no-block meeting-minutes-worker.service"

    if ${pkgs.coreutils}/bin/env -i \
      HOME="$TMPDIR/home" \
      PATH= \
      MEETING_MINUTES_STATE_DIR="$state_dir" \
      MEETING_MINUTES_MEDIA_ROOT="$media_root" \
      SYSTEMCTL_LOG="$systemctl_log" \
      ${pkgs.lib.getExe helper} retry "$job_id" > "$TMPDIR/duplicate.out" 2> "$TMPDIR/duplicate.err"; then
      echo "duplicate retry unexpectedly succeeded" >&2
      exit 1
    fi
    grep -F 'Only failed jobs can be retried' "$TMPDIR/duplicate.err" >/dev/null
    test "$(wc -l < "$systemctl_log")" -eq 2

    jobs_result="$(${pkgs.coreutils}/bin/env -i \
      HOME="$TMPDIR/home" \
      PATH= \
      MEETING_MINUTES_STATE_DIR="$state_dir" \
      MEETING_MINUTES_MEDIA_ROOT="$media_root" \
      SYSTEMCTL_LOG="$systemctl_log" \
      ${pkgs.lib.getExe helper} jobs)"
    jq -e --arg job_id "$job_id" \
      '.schemaVersion == 1 and .jobs[0].job_id == $job_id
        and .jobs[0].phase == "queued" and .jobs[0].attempt == 2' \
      <<< "$jobs_result" >/dev/null

    mkdir -p "$out"
    printf 'ok\n' > "$out/result"
  ''
