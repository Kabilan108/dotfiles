# shellcheck shell=bash
# Optional: log into the dashboard through the admin front with agent-browser
# and check that the model list and Auth Files load. Sourced by run.sh.
# shellcheck disable=SC2154 # run.sh sets the paths, ports and keys

ab() { agent-browser --session "$browser_session" "$@" >>"$out/browser.log" 2>&1; }

login() {
  ab find label "Management Key" fill "$mkey"
  ab find role button click --name Login
  ab wait --text "Quick Start"
}

# A fresh Helium profile holds the page's first requests for about 5 s and then
# reloads the page, which drops a login sent in that window. Retry once after it.
login_with_retry() {
  login && return 0
  echo "login retry after page reload" >>"$out/browser.log"
  ab wait --text "Management Key" && login
}

browser_checks() {
  browser_session=cpa-test-${run##*.}
  section "dashboard in a browser"
  if ! command -v agent-browser >/dev/null; then
    fail "agent-browser is not on PATH"
    return 0
  fi
  check "admin front / opens the dashboard login" ab open "http://127.0.0.1:$test_admin_port/"
  check "login form is shown" ab wait --text "Management Key"
  check "login with the management key shows the sidebar" login_with_retry
  # The dashboard routes by hash and ignores a hash-only open, so use its links.
  ab find role link click --name "Management Center Info"
  check "Available Models lists $model" ab wait --text "$model"
  ab screenshot "$out/dashboard-models.png"
  ab find role link click --name "Auth Files"
  check "Auth Files lists the dummy Codex credential" ab wait --text dummy@example.invalid
  ab screenshot "$out/dashboard-auth-files.png"
  ab close
}
