# shellcheck shell=bash
# Run the packaged preStart and CPA as a transient user unit with the [Service]
# settings of the generated cliproxyapi.service. Sourced by run.sh.
# shellcheck disable=SC2154 # run.sh and resolved.sh set the paths, ports and keys

# These need root, point at the real service, or are replaced below. Every other
# [Service] line, including new sandbox settings, passes through unchanged.
hardened_skip='^(User|Group|EnvironmentFile|ExecStart|Restart|RestartSec|StateDirectory|WorkingDirectory|Environment="CLIPROXY_CONFIG)='

hardened_props() {
  local line in_service=false
  hardened_args=()
  while IFS= read -r line; do
    case $line in
    '[Service]')
      in_service=true
      continue
      ;;
    '['*)
      in_service=false
      continue
      ;;
    esac
    $in_service && [[ -n $line && ! $line =~ $hardened_skip ]] || continue
    # ProtectHome=true would hide the user unit's state directory. tmpfs leaves
    # an empty home with only that directory bound back in.
    if [[ $line == ProtectHome=true ]]; then
      hardened_args+=(-p ProtectHome=tmpfs -p BindPaths="$hardened_state")
      continue
    fi
    hardened_args+=(-p "$line")
  done <<<"$unit_text"
}

write_hardened_config() {
  cat >"$hardened_state/config.yaml" <<EOF
host: 127.0.0.1
port: $hardened_port
auth-dir: $hardened_state/auth
api-keys:
  - $ikey
remote-management:
  allow-remote: true
  secret-key: $mkey
  disable-control-panel: false
debug: false
logging-to-file: true
usage-statistics-enabled: false
management: null
openai-compatibility:
  - name: dummy
    base-url: http://127.0.0.1:$upstream_port/v1
    api-key-entries:
      - api-key: dummy-upstream-key
    models:
      - name: up
        alias: $model
EOF
  chmod 600 "$hardened_state/config.yaml"
}

unit_active() { grep -q '^ActiveState=active$' "$out/hardened-show.txt"; }

journal_clean() {
  ! grep -i -E "bad system call|operation not permitted|permission denied|read-only file system" "$out/hardened-journal.txt"
}

hardened_checks() {
  local api=http://127.0.0.1:$hardened_port config
  local upload='{"type":"claude","email":"dummy@example.invalid","access_token":"dummy","refresh_token":"dummy","expired":"2099-01-01T00:00:00Z"}'
  section "sandboxed user unit"
  hardened_unit=cpa-test-hardened-${run##*.}
  hardened_state=${XDG_STATE_HOME:-$HOME/.local/state}/$hardened_unit
  config=$hardened_state/config.yaml
  mkdir -p "$hardened_state/auth"
  write_hardened_config
  hardened_props
  printf '%s\n' "${hardened_args[@]}" >"$out/hardened-props.txt"

  check "systemd-run starts the unit with the service's [Service] settings" \
    systemd-run --user --quiet --unit "$hardened_unit" --collect \
    "${hardened_args[@]}" \
    -p StateDirectory="$hardened_unit" -p WorkingDirectory="$hardened_state" \
    -E CLIPROXY_CONFIG="$config" -E CLIPROXY_MANAGEMENT_KEY="$mkey" \
    "$cpa" --config "$config"
  wait_http "$api/healthz"
  systemctl --user show "$hardened_unit" -p ActiveState -p SubState -p ProtectSystem -p ProtectHome \
    -p PrivateUsers -p MemoryDenyWriteExecute -p NoNewPrivileges -p SystemCallErrorNumber >"$out/hardened-show.txt"
  check "unit is active" unit_active

  expect_http 200 "GET /healthz" "$api/healthz"
  expect_http 200 "GET /v1/models with key" -H "Authorization: Bearer $ikey" "$api/v1/models"
  expect_http 200 "GET /v0/management/auth-files" -H "Authorization: Bearer $mkey" "$api/v0/management/auth-files"
  expect_http 200 "PUT /v0/management/debug (config write in the state dir)" -X PUT -H "Authorization: Bearer $mkey" -H "Content-Type: application/json" -d '{"value":true}' "$api/v0/management/debug"
  expect_http 200 "POST /v0/management/auth-files (auth file write)" -H "Authorization: Bearer $mkey" -F "file=@-;filename=dummy-claude.json" "$api/v0/management/auth-files" <<<"$upload"
  expect_http 200 "GET /v0/management/auth-files after upload" -H "Authorization: Bearer $mkey" "$api/v0/management/auth-files"
  check "uploaded auth file is listed" body_has dummy-claude.json
  ws_turn_check "ws://127.0.0.1:$hardened_port/v1/responses" hardened

  check "preStart ran in the sandbox (allow-remote=false)" yq_is false '.management."allow-remote"' "$config"
  check "config write persisted" yq_is true '.debug // .observability.logs.debug' "$config"
  check "no main.log in logs/ (file logging off)" no_main_log "$hardened_state"
  check "logs/ holds only per-request error logs" only_error_logs "$hardened_state"

  journalctl --user -u "$hardened_unit" --no-pager -o cat >"$out/hardened-journal.txt" 2>&1
  check "CPA log lines reach the journal (websocket client line)" grep -q "responses websocket: client connected" "$out/hardened-journal.txt"
  check "journal shows no sandbox denials" journal_clean

  systemctl --user stop "$hardened_unit"
  rm -rf "$hardened_state"
  hardened_unit=
  hardened_state=
}
