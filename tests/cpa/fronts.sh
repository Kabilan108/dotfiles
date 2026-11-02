# shellcheck shell=bash
# preStart, CPA and the two nginx fronts from sietch's generated nginx.conf.
# Sourced by run.sh. CPA and nginx stay up for browser_checks; cleanup stops them.
# shellcheck disable=SC2154,SC2034 # run.sh sets the inputs and cleanup reads the pids

# A legacy-layout config shaped like the live file, with file logging still on.
write_legacy_config() {
  cat >"$state/config.yaml" <<EOF
host: 127.0.0.1
port: $api_port
auth-dir: $state/auth
api-keys:
  - $ikey
remote-management:
  allow-remote: true
  secret-key: $mkey
  disable-control-panel: false
  disable-auto-update-panel: true
debug: false
logging-to-file: true
usage-statistics-enabled: false
management: null
# Test only: trust loopback forwarded headers so a request can pose as a tailnet client.
trusted-proxies:
  - 127.0.0.1
openai-compatibility:
  - name: dummy
    base-url: http://127.0.0.1:$upstream_port/v1
    api-key-entries:
      - api-key: dummy-upstream-key
    models:
      - name: up
        alias: $model
EOF
  chmod 600 "$state/config.yaml"
}

# CPA runs from its state directory, like the unit's WorkingDirectory.
start_cpa() {
  (cd "$state" && MANAGEMENT_STATIC_PATH=$panel exec setsid "$cpa" --config "$state/config.yaml") \
    >"$out/cpa-$1.log" 2>&1 &
  cpa_pid=$!
  if ! wait_http "http://127.0.0.1:$api_port/healthz"; then
    fail "CPA ($1) did not start; see $out/cpa-$1.log"
    return 1
  fi
}

stop_cpa() {
  stop_pid "$cpa_pid"
  cpa_pid=
}

run_pre_start() {
  PATH=$unit_path CLIPROXY_CONFIG=$1 CLIPROXY_MANAGEMENT_KEY=$mkey "$pre_start" >"$out/$2.log" 2>&1
}

# yq_is <expected> <yq args...>
yq_is() {
  local want=$1
  shift
  [[ $("$yq" "$@") == "$want" ]]
}

fresh_config_checks() {
  local fresh=$run/fresh/config.yaml
  section "preStart on a missing config"
  mkdir -p "$run/fresh"
  check "preStart writes a fresh config (exit 0)" run_pre_start "$fresh" pre-start-fresh
  check "fresh config: management allow-remote is false" yq_is false '.management."allow-remote"' "$fresh"
  check "fresh config: file logging is off" yq_is false '.observability.logs."logging-to-file"' "$fresh"
  check "fresh config: routing is round-robin" yq_is round-robin '.routing.strategy' "$fresh"
  prod_api_port=$("$yq" '.server.port' "$fresh")
}

legacy_config_checks() {
  local config=$state/config.yaml
  section "preStart on a legacy config"
  # Control: without preStart, file logging writes logs/, so the logging checks can fail.
  # CPA refuses to start on management: null, which preStart fixes, so drop it here.
  write_legacy_config
  "$yq" -i 'del(.management)' "$config"
  if start_cpa control; then
    curl -s -o /dev/null -H "Authorization: Bearer $mkey" "http://127.0.0.1:$api_port/v0/management/config"
    stop_cpa
    check "control: without preStart, file logging writes main.log" has_main_log "$state"
  fi
  rm -rf "$state/logs" "$state/auth/logs"
  write_legacy_config

  check "preStart migrates the legacy config (exit 0)" run_pre_start "$config" pre-start-legacy
  check "pre-v8 backup written" test -e "$config.pre-v8"
  check "legacy config: management allow-remote is false" yq_is false '.management."allow-remote"' "$config"
  check "legacy config: top-level logging-to-file removed" yq_is false 'has("logging-to-file")' "$config"
  check "legacy config: observability file logging is off" yq_is false '.observability.logs."logging-to-file"' "$config"
}

direct_checks() {
  local api=http://127.0.0.1:$api_port
  section "CPA direct (loopback, as sera calls it)"
  start_cpa main || return 1
  expect_http 403 "forwarded tailnet client refused by allow-remote=false" -H "Authorization: Bearer $mkey" -H "X-Forwarded-For: 100.64.0.9" "$api/v0/management/auth-files"
  expect_http 200 "loopback GET /v0/management/auth-files" -H "Authorization: Bearer $mkey" "$api/v0/management/auth-files"
  expect_http "200 400" "loopback POST /v0/management/api-call (key accepted)" -X POST -H "Authorization: Bearer $mkey" -H "Content-Type: application/json" -d "{\"method\":\"GET\",\"url\":\"http://127.0.0.1:$upstream_port/v1/models\"}" "$api/v0/management/api-call"
  expect_http 200 "loopback GET /management.html" "$api/management.html"
}

# Remap every loopback listen to a free port, point proxy_pass at the test CPA,
# and move the pid file and temp paths into the run directory.
write_nginx_conf() {
  local conf=$run/nginx/nginx.conf listen port spare
  local -a edits=(-e "s/127\.0\.0\.1:$prod_api_port;/127.0.0.1:$api_port;/g")
  mkdir -p "$run/nginx/logs" "$run/nginx/tmp"
  while read -r listen; do
    if [[ ! $listen =~ ^listen\ 127\.0\.0\.1:([0-9]+)(\ default_server)?\;$ ]]; then
      fail "nginx.conf has a listen the test cannot remap: $listen"
      return 1
    fi
    port=${BASH_REMATCH[1]}
    case $port in
    "$front_port") spare=$test_front_port ;;
    "$admin_port") spare=$test_admin_port ;;
    *) spare=$(free_ports 1) ;;
    esac
    edits+=(-e "s/listen 127\.0\.0\.1:$port\b/listen 127.0.0.1:$spare/")
  done < <(grep -oE 'listen [^;]+;' "$nginx_conf" | sort -u)
  edits+=(
    -e "s#^pid .*#pid $run/nginx/nginx.pid;#"
    -e "s#^http {#http {\n    client_body_temp_path $run/nginx/tmp/body;\n    proxy_temp_path $run/nginx/tmp/proxy;\n    fastcgi_temp_path $run/nginx/tmp/fastcgi;\n    uwsgi_temp_path $run/nginx/tmp/uwsgi;\n    scgi_temp_path $run/nginx/tmp/scgi;#"
  )
  sed "${edits[@]}" "$nginx_conf" >"$conf"
  diff "$nginx_conf" "$conf" >"$out/nginx-conf.diff"
  return 0
}

start_nginx() {
  local conf=$run/nginx/nginx.conf
  section "nginx fronts"
  check "fronts proxy to the port preStart gives CPA ($prod_api_port)" grep -q "proxy_pass http://127.0.0.1:$prod_api_port;" "$nginx_conf"
  write_nginx_conf || return 1
  check "nginx -t accepts the generated config" "$nginx" -t -q -p "$run/nginx" -e stderr -c "$conf"
  "$nginx" -p "$run/nginx" -e stderr -c "$conf" >"$out/nginx.log" 2>&1 &
  nginx_pid=$!
  check "nginx serves the models front" wait_http "http://127.0.0.1:$test_front_port/healthz"
}

ws_upgrade() {
  curl -s -D "$out/ws-headers" -o /dev/null --max-time 3 -H "Authorization: Bearer $ikey" \
    -H "OpenAI-Beta: responses_websockets=2026-02-06" -H "Connection: Upgrade" -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    -H "Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits" "$1"
}

stream_check() {
  local name=$1 path=$2 rc
  "$python" -I "$here/stream_probe.py" "$test_front_port" "$path" "$model" "$ikey" >"$out/stream-$name.txt" 2>&1
  rc=$?
  if ((rc == 0)); then pass "$name SSE streams incrementally on $path"; else fail "$name SSE on $path (exit $rc; see $out/stream-$name.txt)"; fi
}

ws_turn_check() {
  local url=$1 name=$2 rc
  "$python" -I "$here/ws_probe.py" "$url" "$ikey" "$model" >"$out/ws-turn-$name.txt" 2>&1
  rc=$?
  if ((rc == 0)); then pass "websocket turn streams incrementally ($url)"; else fail "websocket turn on $url (exit $rc; see $out/ws-turn-$name.txt)"; fi
}

models_front_checks() {
  local f=http://127.0.0.1:$test_front_port path
  section "models front (prod $front_port)"
  expect_http 200 "GET /healthz" "$f/healthz"
  expect_http 200 "GET /v1/models with key" -H "Authorization: Bearer $ikey" "$f/v1/models"
  expect_http 401 "GET /v1/models without key (CPA auth answers)" "$f/v1/models"
  expect_http 200 "POST /v1/messages/count_tokens" -H "x-api-key: $ikey" -H "anthropic-version: 2023-06-01" -H "Content-Type: application/json" -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}" "$f/v1/messages/count_tokens"
  expect_http 200 "GET /v1beta/models" -H "x-goog-api-key: $ikey" "$f/v1beta/models"
  expect_http 200 "POST /v1/chat/completions (non-stream)" -H "Authorization: Bearer $ikey" -H "Content-Type: application/json" -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}" "$f/v1/chat/completions"
  expect_http "200 400 404 500 502 503" "POST /backend-api/codex/responses reaches CPA" -H "Authorization: Bearer $ikey" -H "Content-Type: application/json" -d "{\"model\":\"$model\",\"input\":\"hi\"}" "$f/backend-api/codex/responses"
  check "codex route answered by CPA, not nginx" body_lacks "<center>nginx</center>"

  stream_check openai /v1/chat/completions
  stream_check claude /v1/messages

  for path in /v1/responses /backend-api/codex/responses; do
    ws_upgrade "$f$path"
    check "websocket upgrade 101 on $path" grep -q "^HTTP/1.1 101" "$out/ws-headers"
    ws_turn_check "ws://127.0.0.1:$test_front_port$path" "${path//\//_}"
  done

  for path in \
    /v0/management/auth-files \
    /v0/management/config \
    /v0/management/api-call \
    /v0/management/oauth-callback \
    /v8/management/config \
    /v8/management/credentials \
    /v8/management/oauth/callback \
    /v0/resource/plugins/x \
    /management.html \
    / \
    /keep-alive \
    /anthropic/callback \
    /codex/callback \
    /callback \
    /v1/../v0/management/auth-files \
    /v1/%2e%2e/v0/management/auth-files \
    /v1/..%2fv0/management/auth-files \
    /v1/%2E%2E%2Fv0/management/auth-files \
    /v1beta/models/../../v0/management/auth-files \
    //v0/management/auth-files \
    /V0/management/auth-files \
    /v1/%2e%2e/%2e%2e/v0/management/config \
    "/v1/models/..;/../v0/management/auth-files" \
    /healthz/../v0/management/auth-files; do
    # CPA routes /v1/models/*model, so that traversal reaches inference auth (401).
    expect_http "400 401 404" "refuses $path" -H "Authorization: Bearer $mkey" "$f$path"
    check "no management data for $path" body_lacks '"files"'
  done
  expect_http "400 404" "refuses POST /v0/management/api-call" -X POST -H "Authorization: Bearer $mkey" -H "Content-Type: application/json" -d '{}' "$f/v0/management/api-call"
  expect_http "400 404" "refuses PUT /v0/management/config.yaml" -X PUT -H "Authorization: Bearer $mkey" --data-binary 'x: 1' "$f/v0/management/config.yaml"
}

admin_front_checks() {
  local a=http://127.0.0.1:$test_admin_port path method
  section "admin front (prod $admin_port)"
  curl -s -o /dev/null -D "$out/root-headers" "$a/"
  check "GET / returns 302" grep -q "^HTTP/1.1 302" "$out/root-headers"
  check "GET / redirects to relative /management.html" grep -q -i "^location: /management.html" "$out/root-headers"
  curl -s -L -o "$out/panel.html" "$a/"
  check "dashboard served intact (matches the pinned panel)" cmp -s "$out/panel.html" "$panel/management.html"

  expect_http 200 "GET /v8/management/config (dashboard API base)" -H "Authorization: Bearer $mkey" "$a/v8/management/config"
  expect_http 200 "GET /v0/management/config (dashboard legacy probe)" -H "Authorization: Bearer $mkey" "$a/v0/management/config"
  expect_http 200 "GET /v8/management/credentials" -H "Authorization: Bearer $mkey" "$a/v8/management/credentials"
  expect_http 200 "GET /v0/management/auth-files" -H "Authorization: Bearer $mkey" "$a/v0/management/auth-files"
  expect_http 200 "GET /v8/management/routing/model-definitions/claude" -H "Authorization: Bearer $mkey" "$a/v8/management/routing/model-definitions/claude"
  expect_http 200 "PUT /v0/management/debug (write)" -X PUT -H "Authorization: Bearer $mkey" -H "Content-Type: application/json" -d '{"value":false}' "$a/v0/management/debug"
  expect_http 401 "GET /v8/management/config without key" "$a/v8/management/config"
  expect_http 401 "GET /v0/management/config with a wrong key" -H "Authorization: Bearer wrong-dummy-key" "$a/v0/management/config"

  for path in \
    /v1/models/$model \
    /v1/messages \
    /v1/messages/count_tokens \
    /v1/chat/completions \
    /v1/responses \
    /v1beta/models \
    /openai/v1/videos \
    /backend-api/codex/responses \
    /healthz \
    /keep-alive \
    /anthropic/callback \
    /v0/resource/plugins/x \
    /v0/management/../../v1/chat/completions \
    /v8/management/%2e%2e/%2e%2e/v1/chat/completions \
    /management.html/../v1/messages \
    //v1/messages; do
    expect_http "400 404" "refuses $path" -H "Authorization: Bearer $ikey" "$a$path"
    # CPA also 404s a GET on its POST routes, so only nginx's page proves the refusal.
    check "nginx itself refuses $path" body_has "<center>nginx</center>"
  done

  expect_http 200 "GET /v1/models (dashboard model list)" -H "Authorization: Bearer $ikey" "$a/v1/models"
  check "GET /v1/models lists $model" body_has "\"$model\""
  # nginx lets HEAD through; CPA has no HEAD handler here and answers 404 itself.
  expect_http "200 404" "HEAD /v1/models is forwarded" -I -H "Authorization: Bearer $ikey" "$a/v1/models"
  check "HEAD /v1/models answered by CPA, not nginx" grep -q -i "^access-control-allow-headers" "$out/body"
  expect_http 401 "GET /v1/models without key (CPA auth)" "$a/v1/models"
  for method in POST PUT PATCH DELETE OPTIONS; do
    expect_http "403 405" "refuses $method /v1/models" -X "$method" -H "Authorization: Bearer $ikey" -H "Content-Type: application/json" -d '{}' "$a/v1/models"
  done
  expect_http "400 404" "refuses POST /v1/responses" -X POST -H "Authorization: Bearer $ikey" -H "Content-Type: application/json" -d "{\"model\":\"$model\",\"input\":\"hi\"}" "$a/v1/responses"
  ws_upgrade "$a/v1/responses"
  check "refuses the websocket upgrade on /v1/responses" grep -q "^HTTP/1.1 404" "$out/ws-headers"
  expect_http "400 404" "refuses POST /v1/messages" -X POST -H "x-api-key: $ikey" -H "anthropic-version: 2023-06-01" -H "Content-Type: application/json" -d "{\"model\":\"$model\",\"max_tokens\":8,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}" "$a/v1/messages"
  expect_http "400 404" "refuses POST /v1/chat/completions" -X POST -H "Authorization: Bearer $ikey" -H "Content-Type: application/json" -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}" "$a/v1/chat/completions"
}

websockets_flag_checks() {
  local a=http://127.0.0.1:$test_admin_port name=codex-dummy.json
  local select=".files[] | select(.name == \"$name\") | .websockets"
  section "per-credential websockets flag"
  printf '%s\n' '{"type":"codex","email":"dummy@example.invalid","account_id":"dummy-account","access_token":"dummy","refresh_token":"","id_token":"","expired":"2099-01-01T00:00:00Z"}' >"$run/$name"
  expect_http 200 "upload a dummy Codex auth file" -H "Authorization: Bearer $mkey" -F "file=@$run/$name;filename=$name" "$a/v0/management/auth-files"
  expect_http 200 "PATCH /v8/management/credentials/fields websockets=true" -X PATCH -H "Authorization: Bearer $mkey" -H "Content-Type: application/json" -d "{\"name\":\"$name\",\"websockets\":true}" "$a/v8/management/credentials/fields"
  expect_http 200 "GET /v8/management/credentials" -H "Authorization: Bearer $mkey" "$a/v8/management/credentials"
  check "credential listing shows websockets=true" yq_is true -p=json -o=yaml "$select" "$out/body"
  check "auth file on disk has websockets=true" yq_is true -p=json -o=yaml '.websockets' "$state/auth/$name"
}

logging_checks() {
  section "logging"
  check "CPA log lines go to stdout (websocket client line)" grep -q "responses websocket: client connected" "$out/cpa-main.log"
  check "no main.log in logs/ (file logging off)" no_main_log "$state"
  check "logs/ holds only per-request error logs" only_error_logs "$state"
}

fronts_checks() {
  fresh_config_checks
  legacy_config_checks
  direct_checks || return 0
  start_nginx || return 0
  models_front_checks
  admin_front_checks
  websockets_flag_checks
  logging_checks
}
