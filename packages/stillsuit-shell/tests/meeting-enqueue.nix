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
      '.job_id == $job_id and .phase == "queued" and .recording_path == $recording' \
      "$state_dir/jobs/$job_id.json" >/dev/null
    test "$(<"$systemctl_log")" = \
      "--user start --no-block meeting-minutes-worker.service"

    mkdir -p "$out"
    printf 'ok\n' > "$out/result"
  ''
