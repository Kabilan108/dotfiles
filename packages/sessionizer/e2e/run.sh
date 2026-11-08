#!/usr/bin/env bash
# Usage: run.sh BINARY
# End-to-end run of the picker and proxy sessions against a throwaway fixture
# of three tmux servers and a fake ssh. It never touches your own tmux.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
BIN=$(realpath "$1")
FIXTURE=$(mktemp -d /tmp/sz-e2e.XXXXXX)
bash "$HERE/setup.sh" "$BIN" "$FIXTURE" >/dev/null || exit 1
. "$FIXTURE/env.sh"
failures=0
check() {
  if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; else echo "FAIL  $1"; failures=$((failures + 1)); fi
}
popup() { waitfor '! screen | grep -qE "[┌┐└┘]"'; (key M-s >/dev/null 2>&1 &); waitfor 'screen | grep -q "insert>"' && waitfor '! screen | grep -q "󰑓"'; }
# The picker's list is the column between the popup's border and the
# preview's. Each row takes two lines; its first is bar, kind icon, name.
list_column() { awk -F'│' '{ print $2 }'; }
row_tops() { list_column | grep -E '^(▌| ) [^ ]'; }
# first_row prints the first row's top line, which must sit in a HERE section
# right under the rule below the prompt.
first_row() { awk -F'│' 'state == 1 { if ($2 !~ /^HERE /) exit; state = 2; next } state == 2 { print $2; exit } !state && /│─────/ { state = 1 }'; }
type_keys() { local text=$1 i; for ((i = 0; i < ${#text}; i++)); do key "${text:i:1}"; done; }
local_session() { L list-clients -F '#{session_name}' | head -1; }
remote_session() { R list-clients -F '#{session_name}' | head -1; }
proxy_pid() { L list-panes -t =sessionizer-fakeremote: -F '#{pane_pid}' 2>/dev/null; }

L new-session -d -s sessionizer-fakeremote "sleep 600"
decoy_pid=$(proxy_pid)
popup; type_keys r-one; key Enter
waitfor '! screen | grep -qE "[┌┐└┘]"'
check "a same-named ordinary session is left alone" '[ "$(proxy_pid)" = "$decoy_pid" ] && [ -z "$(L show-options -qv -t =sessionizer-fakeremote: @sessionizer-proxy-host)" ] && [ "$(local_session)" = alpha ] && [ -z "$(remote_session)" ]'
L kill-session -t =sessionizer-fakeremote


popup
screen > "$F/screen-1.txt"
check "inventory goes over the agent alias with the gate's exact command" \
  'grep -qx -- "-o BatchMode=yes -o ConnectTimeout=2 fakeremote-agent \"\$HOME/bin/sessionizer\" --inventory" $F/ssh.log'
check "current session is row 1 and marked here" 'first_row < $F/screen-1.txt | grep -q " alpha .*here"'
check "cursor starts on row 2" 'row_tops < $F/screen-1.txt | sed -n 2p | grep -q "^▌.* beta "'
check "local directories sort before remote directories" \
  '[ "$(list_column < $F/screen-1.txt | grep -n " gamma " | cut -d: -f1)" -lt "$(list_column < $F/screen-1.txt | grep -n " rdir " | cut -d: -f1)" ]'

type_keys r-one; key Enter
waitfor '[ "$(remote_session)" = r-one ]'
check "remote session opens through a proxy" '[ "$(local_session)" = sessionizer-fakeremote ] && [ "$(remote_session)" = r-one ]'
check "proxy passes keys through" '[ "$(L show-options -v -t =sessionizer-fakeremote: key-table)" = sessionizer-proxy ] && [ "$(L show-options -v -t =sessionizer-fakeremote: prefix)" = None ] && [ "$(L show-options -v -t =sessionizer-fakeremote: status)" = off ]'
first_pid=$(proxy_pid)

type_keys "echo marker-123"; key Enter
waitfor 'R capture-pane -p -t =r-one: | grep -q "^marker-123"'
check "typing reaches the remote pane" 'R capture-pane -p -t =r-one: | grep -q "^marker-123"'

popup
screen > "$F/screen-2.txt"
check "M-s inside the proxy opens the local picker, not the remote binding" '[ ! -e $F/remote-saw-ms ] && grep -q "insert>" $F/screen-2.txt'
check "picker marks the remote session as here" 'first_row < $F/screen-2.txt | grep -q " r-one .*here"'
type_keys r-two; key Enter
waitfor '[ "$(remote_session)" = r-two ]'
check "switching remote sessions reuses the proxy" '[ "$(remote_session)" = r-two ] && [ "$(proxy_pid)" = "$first_pid" ] && [ "$(local_session)" = sessionizer-fakeremote ]'
check "the switch rides the login connection without auth" 'grep -- "--proxy-switch" $F/ssh.log | grep -q "ControlMaster=no -o BatchMode=yes -o PubkeyAuthentication=no"'

popup; type_keys beta; key Enter
waitfor '[ "$(local_session)" = beta ]'
check "local session switch leaves the proxy running" '[ "$(local_session)" = beta ] && [ "$(proxy_pid)" = "$first_pid" ] && [ "$(remote_session)" = r-two ]'

popup; type_keys rdir2; key Enter
waitfor '[ "$(remote_session)" = rdir2 ]'
check "remote directory opens a new remote session" '[ "$(remote_session)" = rdir2 ] && [ "$(local_session)" = sessionizer-fakeremote ] && [ "$(R show-options -v -t =rdir2: @sessionizer-path)" = "$F/remote-home/repos/rdir2" ]'

key C-a; key d
waitfor '! L has-session -t =sessionizer-fakeremote'
check "remote prefix d closes the proxy and returns to a local session" '! L has-session -t =sessionizer-fakeremote && [ "$(local_session)" = beta ]'

popup; type_keys "rdir !rdir2"; key Enter
waitfor '[ "$(remote_session)" = rdir ]'
popup

check "a directory opened by a fresh proxy is marked here" 'screen | first_row | grep -q " rdir .*here"'
key Escape; key Escape
waitfor '! screen | grep -qE "[┌┐└┘]"'
R switch-client -c "$(R list-clients -F "#{client_name}" | head -1)" -t =r-two
sleep 1.1
popup
check "switching inside the remote tmux moves here" 'screen | first_row | grep -q " r-two .*here"'
key Escape; key Escape
waitfor '! screen | grep -qE "[┌┐└┘]"'
key C-a; key d
waitfor '! L has-session -t =sessionizer-fakeremote'

sleep 1.1; L set-environment -g FAKE_SSH_DOWN 1
popup; type_keys r-one; key Enter
waitfor 'L list-panes -t =sessionizer-fakeremote: -F "#{pane_dead}" | grep -q 1'
check "failed ssh keeps the proxy pane with its error" 'L list-panes -t =sessionizer-fakeremote: -F "#{pane_dead} #{pane_dead_status}" | grep -q "1 255" && [ "$(local_session)" = sessionizer-fakeremote ]'
L set-environment -gu FAKE_SSH_DOWN
L switch-client -c "$(client)" -t =beta
waitfor '[ "$(local_session)" = beta ]'; sleep 1.1
popup; type_keys r-one; key Enter
waitfor '[ "$(remote_session)" = r-one ]'
check "a stale proxy is replaced" '[ "$(remote_session)" = r-one ] && L list-panes -t =sessionizer-fakeremote: -F "#{pane_dead}" | grep -qx 0'

sleep 1.1; popup; type_keys alpha; key Enter
waitfor '[ "$(local_session)" = alpha ]'
popup
screen > "$F/screen-3.txt"
check "picker opened from alpha starts on the previous session (the remote one)" 'row_tops < $F/screen-3.txt | sed -n 2p | grep -q "^▌.* r-one "'
key Escape; key Escape
waitfor '! screen | grep -qE "[┌┐└┘]"'

popup; type_keys r-one; key Enter
waitfor '[ "$(local_session)" = sessionizer-fakeremote ] && [ "$(remote_session)" = r-one ]'
R kill-server
waitfor 'L list-panes -t =sessionizer-fakeremote: -F "#{pane_dead}" | grep -qx 1'
waitfor 'screen | grep -q "Press any key to close this proxy"'
check "a dead proxy says how to leave it" 'screen | grep -q "ssh to fakeremote ended (status 1). Press any key to close this proxy."'
key M-s
waitfor '! L has-session -t =sessionizer-fakeremote'
check "any key, M-s included, closes a dead proxy and lands on a local session" '! L has-session -t =sessionizer-fakeremote && case "$(local_session)" in alpha|beta) true ;; *) false ;; esac'

echo "failures=$failures"
D kill-server 2>/dev/null; L kill-server 2>/dev/null; R kill-server 2>/dev/null
rm -rf "$S" "$FIXTURE"
exit "$failures"
