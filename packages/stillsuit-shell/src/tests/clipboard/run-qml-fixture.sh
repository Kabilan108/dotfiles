#!/usr/bin/env bash
# Loads the clipboard Service.qml offscreen against the real collector and a
# scripted fake `wl-paste --watch`, then checks what it left on disk.

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$script_dir/../.." && pwd)
collector=${STILLSUIT_CLIPBOARD_COLLECTOR:-$(cd -- "$source_root/.." && pwd)/bin/stillsuit-clipboard-collector}
fixture_root=$(mktemp -d)

cleanup() {
    pkill -KILL -f -- "$fixture_root" 2>/dev/null || true
    rm -rf -- "$fixture_root"
}
trap cleanup EXIT

export HOME="$fixture_root/home"
export XDG_CONFIG_HOME="$fixture_root/config"
export XDG_DATA_HOME="$fixture_root/data"
export XDG_STATE_HOME="$fixture_root/state"
export XDG_CACHE_HOME="$fixture_root/cache"
export XDG_RUNTIME_DIR="$fixture_root/runtime"
export QT_QPA_PLATFORM=offscreen
export STILLSUIT_CONFIG_ID=stillsuit-clipboard-fixture
# Each fake wl-paste call is a Python startup; a classification makes several,
# which alone can take a large share of the collector's text bound.
export STILLSUIT_CLIPBOARD_TEXT_GATE_SEC=2
unset DBUS_SESSION_BUS_ADDRESS WAYLAND_DISPLAY

mkdir -p "$HOME" "$XDG_CONFIG_HOME/quickshell" "$XDG_DATA_HOME" "$XDG_STATE_HOME" \
    "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

fake="$fixture_root/fake"
state_root="$XDG_STATE_HOME/stillsuit"
mkdir -p "$fake/scenarios"
export FAKE_CLIP_DIR="$fake"
export CLIP_FIXTURE_FAKE_DIR="$fake"
export CLIP_FIXTURE_STATE_ROOT="$state_root"
export CLIP_FIXTURE_COLLECTOR="$collector"
export CLIP_FIXTURE_WL_PASTE="$script_dir/fake-wl-paste"
export CLIP_FIXTURE_WL_COPY="$script_dir/fake-wl-copy"
export CLIP_FIXTURE_IDLE_WL_PASTE="$fixture_root/idle-wl-paste"

printf '#!/usr/bin/env python3\nimport time\ntime.sleep(3600)\n' >"$CLIP_FIXTURE_IDLE_WL_PASTE"
chmod +x "$CLIP_FIXTURE_IDLE_WL_PASTE"

# scenario <dir> <type> <payload-file> [<type> <payload-file>]...
# The first type is the one wl-paste would pipe to the watch command.
scenario() {
    local dir=$1
    shift
    mkdir -p "$dir/payloads"
    : >"$dir/types"
    local mime file
    while (($# >= 2)); do
        mime=$1
        file=$2
        shift 2
        printf '%s\n' "$mime" >>"$dir/types"
        cp -- "$file" "$dir/payloads/$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$mime")"
    done
}

payloads="$fixture_root/payloads"
mkdir -p "$payloads"
printf 'alpha line\n' >"$payloads/alpha"
printf 'bravo line\n' >"$payloads/bravo"
printf 'charlie line\n' >"$payloads/charlie"
printf 'SECRET-from-bitwarden' >"$payloads/secret"
: >"$payloads/zero"
printf 'https://example.com/page' >"$payloads/page-url"
printf 'chrome-extension://nngceckbapebfimnlniiiahkandclblb/offscreen-document/index.html' >"$payloads/bw-url"
printf '\x89PNG\r\n\x1a\nfixture-image' >"$payloads/png"

scenario "$fake/scenarios/01" "text/plain;charset=utf-8" "$payloads/alpha" "chromium/x-source-url" "$payloads/page-url"
scenario "$fake/scenarios/02" "text/plain;charset=utf-8" "$payloads/bravo"
scenario "$fake/scenarios/03" "image/png" "$payloads/png"
scenario "$fake/scenarios/04" "text/plain;charset=utf-8" "$payloads/secret" "chromium/x-source-url" "$payloads/bw-url"
scenario "$fake/scenarios/05" "text/plain;charset=utf-8" "$payloads/alpha"
# Another sender offers the types charlie was copied with and fails, so the
# read is zero bytes. Without Gecko's shape that is no clear: charlie stays.
scenario "$fake/scenarios/06" "text/plain;charset=utf-8" "$payloads/charlie" "chromium/x-source-url" "$payloads/page-url"
printf 'gate-1\n' >"$fake/scenarios/06/gate"
scenario "$fake/scenarios/07" "text/plain;charset=utf-8" "$payloads/zero" "chromium/x-source-url" "$payloads/page-url"
mkdir -p "$fake/scenarios/08"
printf '3\n' >"$fake/scenarios/08/exit"

hex() { printf '%s' "$1" | sha256sum | cut -c1-64; }
private_dir() { mkdir -p -- "$1" && chmod 700 -- "$1"; }

# Expiry instance (ttlHours 0.1 = 360 s): e1 expires 8 s from now. e3 has no
# blob, so copying it drops the entry; e2's copy fails for want of wl-copy and
# keeps it.
expiry_root="$XDG_STATE_HOME/expiry"
private_dir "$expiry_root/clipboard"
private_dir "$expiry_root/clipboard/blobs"
e1=$(hex e1) e2=$(hex e2) e3=$(hex e3)
printf 'e2' >"$expiry_root/clipboard/blobs/$e2"
now_ms=$(date +%s%3N)
cat >"$expiry_root/clipboard/history.v1.json" <<HISTORY
{"schemaVersion":1,"entries":[
{"sha":"$e2","kind":"text","mime":"text/plain","bytes":2,"preview":"e2","lastUsed":$((now_ms - 100000))},
{"sha":"$e3","kind":"text","mime":"text/plain","bytes":2,"preview":"e3","lastUsed":$((now_ms - 200000))},
{"sha":"$e1","kind":"text","mime":"text/plain","bytes":2,"preview":"e1","lastUsed":$((now_ms - 352000))}]}
HISTORY
export CLIP_FIXTURE_EXPIRY_ROOT="$expiry_root"
export CLIP_FIXTURE_MISSING_WL_COPY="$fixture_root/no-such-wl-copy"
export CLIP_FIXTURE_EXPIRY_IDS="$e1 $e2 $e3"

# Sweep instance (gcGraceSec 4): a young orphan and a staging file, both
# eligible 20 s from now (the staging file by its 600 s minimum age, well past
# the grace), which the first sweep defers and one follow-up at that time
# removes, and a future-dated orphan no sweep removes.
sweep_root="$XDG_STATE_HOME/sweep"
private_dir "$sweep_root/clipboard"
private_dir "$sweep_root/clipboard/blobs"
young=$(hex young-orphan) future=$(hex future-orphan)
staging="$sweep_root/clipboard/blobs/.tmp-1-staging"
printf 'y' >"$sweep_root/clipboard/blobs/$young"
printf 's' >"$staging"
printf 'f' >"$sweep_root/clipboard/blobs/$future"
sweep_now=$(date +%s)
touch -d "@$((sweep_now + 16))" "$sweep_root/clipboard/blobs/$young"
touch -d "@$((sweep_now - 580))" "$staging"
touch -d "@$((sweep_now + 3600))" "$sweep_root/clipboard/blobs/$future"
counting_collector="$fixture_root/counting-collector"
cat >"$counting_collector" <<WRAPPER
#!/usr/bin/env bash
printf '%s\n' "\$1" >>'$fixture_root/sweep-calls'
exec '$collector' "\$@"
WRAPPER
chmod +x "$counting_collector"
export CLIP_FIXTURE_SWEEP_ROOT="$sweep_root"
export CLIP_FIXTURE_SWEEP_COLLECTOR="$counting_collector"
export CLIP_FIXTURE_SWEEP_CALLS="$fixture_root/sweep-calls"
export CLIP_FIXTURE_SWEEP_YOUNG="$sweep_root/clipboard/blobs/$young"
export CLIP_FIXTURE_SWEEP_FUTURE="$sweep_root/clipboard/blobs/$future"
export CLIP_FIXTURE_SWEEP_STAGING="$staging"

# scripted <name>: a fake wl-paste with its own scenario directory.
scripted() {
    local name=$1
    mkdir -p "$fixture_root/$name-fake/scenarios"
    cat >"$fixture_root/$name-wl-paste" <<WRAPPER
#!/usr/bin/env bash
FAKE_CLIP_DIR='$fixture_root/$name-fake' exec '$script_dir/fake-wl-paste' "\$@"
WRAPPER
    chmod +x "$fixture_root/$name-wl-paste"
}

# firefox_offer <dir> <text-file> [<moz-origin-file>]: Gecko's plain-text
# targets as probed, with a page origin when given.
firefox_offer() {
    local dir=$1 text=$2 origin=${3:-}
    local args=("text/plain;charset=utf-8" "$text" UTF8_STRING "$text" COMPOUND_TEXT "$payloads/empty"
        TEXT "$text" text/plain "$text" STRING "$text" "text/plain;charset=utf-8" "$text" text/plain "$text")
    [[ -n $origin ]] && args+=(text/x-moz-url-priv "$origin")
    args+=(SAVE_TARGETS "$payloads/empty")
    scenario "$dir" "${args[@]}"
}

: >"$payloads/empty"
printf 'GECKO-page-copy' >"$payloads/gecko-page"
printf 'GECKO-secret-password' >"$payloads/gecko-secret"
printf 'GECKO-done' >"$payloads/gecko-done"
printf 'RECORD-password' >"$payloads/record-password"
printf 'RECORD-done' >"$payloads/record-done"
printf 'RECORD-after' >"$payloads/record-after"
python3 -c 'import sys; sys.stdout.buffer.write("http://localhost:8333".encode("utf-16-le"))' >"$payloads/page-origin"
printf '\x14\x00\x00\x00\x2d\x00\x00\x00token' >"$payloads/rfh-token"
printf 'chrome-extension://nngceckbapebfimnlniiiahkandclblb/offscreen-document/index.html' >"$payloads/bw-offscreen"

# Gecko instance (unattributedFirefox skip) replays the Wayland probe: a
# Firefox page copy, the Bitwarden extension's password copy, the nil
# announcement, Firefox's zero-byte clear and Chromium's text-less clear. Only
# the page copy and the closing sentinel may be recorded.
scripted gecko
g=$fixture_root/gecko-fake/scenarios
firefox_offer "$g/01" "$payloads/gecko-page" "$payloads/page-origin"
firefox_offer "$g/02" "$payloads/gecko-secret"
firefox_offer "$g/03" "$payloads/empty"
printf 'nil\n' >"$g/03/state"
firefox_offer "$g/04" "$payloads/empty"
scenario "$g/05" "chromium/x-internal-source-rfh-token" "$payloads/rfh-token" \
    "chromium/x-source-url" "$payloads/bw-offscreen"
scenario "$g/06" "text/plain;charset=utf-8" "$payloads/gecko-done"

# Record instance (unattributedFirefox record): the extension's copy, nil, a
# duplicate data event, nil, then the clear, which purges the copy. Then
# another app offers text with other types and sends no bytes; that empty
# read must not purge the sentinel.
scripted record
r=$fixture_root/record-fake/scenarios
firefox_offer "$r/01" "$payloads/record-password"
firefox_offer "$r/02" "$payloads/empty"
printf 'nil\n' >"$r/02/state"
firefox_offer "$r/03" "$payloads/record-password"
firefox_offer "$r/04" "$payloads/empty"
printf 'nil\n' >"$r/04/state"
firefox_offer "$r/05" "$payloads/empty"
scenario "$r/06" "text/plain;charset=utf-8" "$payloads/record-done"
scenario "$r/07" "text/plain;charset=utf-8" "$payloads/empty" text/plain "$payloads/empty" \
    UTF8_STRING "$payloads/empty"
scenario "$r/08" "text/plain;charset=utf-8" "$payloads/record-after" text/plain "$payloads/record-after"
export CLIP_FIXTURE_GECKO_ROOT="$XDG_STATE_HOME/gecko"
export CLIP_FIXTURE_GECKO_PASTE="$fixture_root/gecko-wl-paste"
export CLIP_FIXTURE_RECORD_ROOT="$XDG_STATE_HOME/record"
export CLIP_FIXTURE_RECORD_PASTE="$fixture_root/record-wl-paste"
CLIP_FIXTURE_RECORD_SHA=$(hex RECORD-password)
export CLIP_FIXTURE_RECORD_SHA

# Pending instance: removals survive shutdown and failure. Two young blobs
# (younger than the 120 s gc grace, so only an explicit rm deletes them in
# time) and collectors whose rm is slow or always fails.
pending_root="$XDG_STATE_HOME/pending"
private_dir "$pending_root/clipboard"
private_dir "$pending_root/clipboard/blobs"
px=$(hex pending-x) py=$(hex pending-y)
printf 'pending-x' >"$pending_root/clipboard/blobs/$px"
printf 'pending-y' >"$pending_root/clipboard/blobs/$py"
touch -d "@$(($(date +%s) - 30))" "$pending_root/clipboard/blobs/$px" "$pending_root/clipboard/blobs/$py"
cat >"$pending_root/clipboard/history.v1.json" <<HISTORY
{"schemaVersion":1,"entries":[
{"sha":"$px","kind":"text","mime":"text/plain","bytes":9,"preview":"pending-x","lastUsed":$((now_ms - 1000))},
{"sha":"$py","kind":"text","mime":"text/plain","bytes":9,"preview":"pending-y","lastUsed":$((now_ms - 2000))}]}
HISTORY
cat >"$fixture_root/slow-collector" <<WRAPPER
#!/usr/bin/env bash
[[ \$1 == rm ]] && sleep 2
exec '$collector' "\$@"
WRAPPER
cat >"$fixture_root/failing-collector" <<WRAPPER
#!/usr/bin/env bash
if [[ \$1 == rm ]]; then printf 'rm\n' >>'$fixture_root/failing-calls'; exit 1; fi
exec '$collector' "\$@"
WRAPPER
chmod +x "$fixture_root/slow-collector" "$fixture_root/failing-collector"
export CLIP_FIXTURE_PENDING_ROOT="$pending_root"
export CLIP_FIXTURE_PENDING_X="$px" CLIP_FIXTURE_PENDING_Y="$py"
export CLIP_FIXTURE_SLOW_COLLECTOR="$fixture_root/slow-collector"
export CLIP_FIXTURE_FAILING_COLLECTOR="$fixture_root/failing-collector"
export CLIP_FIXTURE_FAILING_CALLS="$fixture_root/failing-calls"

# Normalize instance: a history written while the clock ran ahead, with a
# field this version no longer keeps, is written back normalized.
normalize_root="$XDG_STATE_HOME/normalize"
private_dir "$normalize_root/clipboard"
nz=$(hex normalize-z)
cat >"$normalize_root/clipboard/history.v1.json" <<HISTORY
{"schemaVersion":1,"entries":[{"sha":"$nz","kind":"text","mime":"text/plain","bytes":1,"preview":"z","lastUsed":$((now_ms + 7200000)),"unattributed":true}]}
HISTORY
export CLIP_FIXTURE_NORMALIZE_ROOT="$normalize_root"

# Durable instance: a commit that drops entries is on disk before its `rm`
# starts. The collector's rm snapshots the history it starts under; gc is a
# no-op so it cannot re-tighten the state directory the fixture makes
# read-only to fail a save.
durable_root="$XDG_STATE_HOME/durable"
private_dir "$durable_root/clipboard"
private_dir "$durable_root/clipboard/blobs"
dx=$(hex durable-x) dy=$(hex durable-y)
printf 'durable-x' >"$durable_root/clipboard/blobs/$dx"
printf 'durable-y' >"$durable_root/clipboard/blobs/$dy"
touch -d "@$(($(date +%s) - 30))" "$durable_root/clipboard/blobs/$dx" "$durable_root/clipboard/blobs/$dy"
cat >"$durable_root/clipboard/history.v1.json" <<HISTORY
{"schemaVersion":1,"entries":[
{"sha":"$dx","kind":"text","mime":"text/plain","bytes":9,"preview":"durable-x","lastUsed":$((now_ms - 1000))},
{"sha":"$dy","kind":"text","mime":"text/plain","bytes":9,"preview":"durable-y","lastUsed":$((now_ms - 2000))}]}
HISTORY
cat >"$fixture_root/durable-collector" <<WRAPPER
#!/usr/bin/env bash
calls='$fixture_root/durable-calls'
case \$1 in
rm)
    cp -- '$durable_root/clipboard/history.v1.json' "$fixture_root/durable-snapshot-\$(cat "\$calls" 2>/dev/null | wc -l)"
    printf 'rm\n' >>"\$calls"
    ;;
gc)
    printf '{"ok":true,"removed":0,"deferred":0}\n'
    exit 0
    ;;
esac
exec '$collector' "\$@"
WRAPPER
chmod +x "$fixture_root/durable-collector"
export CLIP_FIXTURE_DURABLE_ROOT="$durable_root"
export CLIP_FIXTURE_DURABLE_X="$dx" CLIP_FIXTURE_DURABLE_Y="$dy"
export CLIP_FIXTURE_DURABLE_COLLECTOR="$fixture_root/durable-collector"
export CLIP_FIXTURE_DURABLE_CALLS="$fixture_root/durable-calls"
export CLIP_FIXTURE_DURABLE_SNAPSHOTS="$fixture_root/durable-snapshot-"

# Gc-gate instance: while a write that drops an entry keeps failing, no gc
# runs, and none is ever asked to delete a blob the history on disk lists.
# Its gc only records each call: the state directory mode (the fixture makes
# it read-only to fail the write) and the listed shas missing from --keep. The
# watcher exits once, on the fixture's signal, which schedules a gc.
scripted gcgate
gcgate_root="$XDG_STATE_HOME/gcgate"
private_dir "$gcgate_root/clipboard"
private_dir "$gcgate_root/clipboard/blobs"
gx=$(hex gcgate-x) gy=$(hex gcgate-y)
printf 'gcgate-x' >"$gcgate_root/clipboard/blobs/$gx"
printf 'gcgate-y' >"$gcgate_root/clipboard/blobs/$gy"
touch -d "@$(($(date +%s) - 3600))" "$gcgate_root/clipboard/blobs/$gx" "$gcgate_root/clipboard/blobs/$gy"
cat >"$gcgate_root/clipboard/history.v1.json" <<HISTORY
{"schemaVersion":1,"entries":[
{"sha":"$gx","kind":"text","mime":"text/plain","bytes":8,"preview":"gcgate-x","lastUsed":$((now_ms - 1000))},
{"sha":"$gy","kind":"text","mime":"text/plain","bytes":8,"preview":"gcgate-y","lastUsed":$((now_ms - 2000))}]}
HISTORY
mkdir -p "$fixture_root/gcgate-fake/scenarios/01"
printf 'gcgate-go\n' >"$fixture_root/gcgate-fake/scenarios/01/gate"
printf '3\n' >"$fixture_root/gcgate-fake/scenarios/01/exit"
cat >"$fixture_root/gcgate-collector" <<WRAPPER
#!/usr/bin/env python3
import json, os, stat, sys
args = sys.argv[1:]
if args[:1] == ["gc"]:
    keep = args[args.index("--keep") + 1:] if "--keep" in args else []
    with open("$gcgate_root/clipboard/history.v1.json", encoding="utf-8") as history:
        listed = [entry["sha"] for entry in json.load(history)["entries"]]
    mode = stat.S_IMODE(os.stat("$gcgate_root/clipboard").st_mode)
    with open("$fixture_root/gcgate-calls", "a", encoding="utf-8") as calls:
        calls.write(json.dumps({"mode": oct(mode), "missing": [sha for sha in listed if sha not in keep]}) + "\n")
    print(json.dumps({"ok": True, "removed": 0, "deferred": 0}))
    sys.exit(0)
os.execv("$collector", ["$collector", *args])
WRAPPER
chmod +x "$fixture_root/gcgate-collector"
export CLIP_FIXTURE_GCGATE_ROOT="$gcgate_root"
export CLIP_FIXTURE_GCGATE_X="$gx" CLIP_FIXTURE_GCGATE_Y="$gy"
export CLIP_FIXTURE_GCGATE_COLLECTOR="$fixture_root/gcgate-collector"
export CLIP_FIXTURE_GCGATE_PASTE="$fixture_root/gcgate-wl-paste"
export CLIP_FIXTURE_GCGATE_FAKE="$fixture_root/gcgate-fake"
export CLIP_FIXTURE_GCGATE_CALLS="$fixture_root/gcgate-calls"

# Model instance: a fixture model is the only input; no helper runs.
model_collector="$fixture_root/model-collector"
cat >"$model_collector" <<WRAPPER
#!/usr/bin/env bash
printf '%s\n' "\$1" >>'$fixture_root/model-calls'
exec '$collector' "\$@"
WRAPPER
chmod +x "$model_collector"
export CLIP_FIXTURE_MODEL_COLLECTOR="$model_collector"
export CLIP_FIXTURE_MODEL_CALLS="$fixture_root/model-calls"
export CLIP_FIXTURE_MODEL_ROOT="$XDG_STATE_HOME/model"

# Late-model instance: its copy, rm and gc hang until killed, recording their
# pids, so attaching a model must stop them.
late_root="$XDG_STATE_HOME/model-late"
private_dir "$late_root/clipboard"
l1=$(hex late-1) l2=$(hex late-2)
cat >"$late_root/clipboard/history.v1.json" <<HISTORY
{"schemaVersion":1,"entries":[
{"sha":"$l1","kind":"text","mime":"text/plain","bytes":6,"preview":"late-1","lastUsed":$((now_ms - 1000))},
{"sha":"$l2","kind":"text","mime":"text/plain","bytes":6,"preview":"late-2","lastUsed":$((now_ms - 2000))}]}
HISTORY
cat >"$fixture_root/hanging-collector" <<WRAPPER
#!/usr/bin/env bash
case \$1 in
copy|rm|gc)
    printf '%s' "\$\$" >"$fixture_root/late-\$1.pid"
    exec python3 -c 'import time; time.sleep(60)' '$fixture_root/hanging'
    ;;
esac
exec '$collector' "\$@"
WRAPPER
chmod +x "$fixture_root/hanging-collector"
export CLIP_FIXTURE_LATE_ROOT="$late_root"
export CLIP_FIXTURE_LATE_IDS="$l1 $l2"
export CLIP_FIXTURE_HANGING_COLLECTOR="$fixture_root/hanging-collector"
export CLIP_FIXTURE_LATE_PIDS="$fixture_root/late-"

fixture_config="$XDG_CONFIG_HOME/quickshell/$STILLSUIT_CONFIG_ID"
cp -R -- "$source_root" "$fixture_config"
cp -- "$script_dir/fixture-shell.qml" "$fixture_config/shell.qml"

status=0
timeout 90s quickshell --config "$STILLSUIT_CONFIG_ID" --no-color \
    >"$fixture_root/quickshell.log" 2>&1 || status=$?
if [[ $status -ne 0 ]] || rg -n 'ERROR qml| ERROR:|CLIPBOARD_FIXTURE_FAIL|ReferenceError|TypeError' \
        "$fixture_root/quickshell.log" >/dev/null; then
    sed -n '1,200p' "$fixture_root/quickshell.log" >&2
    printf 'clipboard QML fixture failed (quickshell exit %s)\n' "$status" >&2
    exit 1
fi
grep -F 'CLIPBOARD_FIXTURE_OK' "$fixture_root/quickshell.log"

clip="$state_root/clipboard"
mode() { stat -c '%a' -- "$1"; }
fail() { printf 'clipboard QML fixture: %s\n' "$1" >&2; exit 1; }
[[ $(mode "$clip") == 700 ]] || fail "state dir mode $(mode "$clip")"
[[ $(mode "$clip/blobs") == 700 ]] || fail "blob dir mode $(mode "$clip/blobs")"
[[ $(mode "$clip/history.v1.json") == 600 ]] || fail "history mode $(mode "$clip/history.v1.json")"
[[ -z $(ls -A -- "$clip/blobs") ]] || fail "orphan blobs survived clear: $(ls -A -- "$clip/blobs")"
jq -e '.schemaVersion == 1 and (.entries | length) == 0' "$clip/history.v1.json" >/dev/null \
    || fail "history not cleared"
if rg -a -l 'SECRET-from-bitwarden' "$state_root" "$fixture_root/quickshell.log"; then
    fail "secret content reached disk or logs"
fi
if rg -a -l 'GECKO-secret-password' "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR" "$fixture_root/quickshell.log"; then
    fail "an unattributed Firefox copy reached disk or logs"
fi
[[ ! -e $XDG_STATE_HOME/record/clipboard/blobs/$CLIP_FIXTURE_RECORD_SHA ]] || fail "purged copy's blob survived"
[[ ! -e $fixture_root/model-calls ]] || fail "the model-driven service ran the collector: $(tr '\n' ' ' <"$fixture_root/model-calls")"
[[ ! -e $XDG_STATE_HOME/model ]] || fail "the model-driven service touched its state root"
jq -e '(.entries | length) == 0 and (.pendingRemovals // [] | length) == 0' \
    "$durable_root/clipboard/history.v1.json" >/dev/null || fail "durable history not settled"
[[ $(grep -cx gc "$fixture_root/sweep-calls") == 2 ]] \
    || fail "expected one sweep and one follow-up, got: $(tr '\n' ' ' <"$fixture_root/sweep-calls")"
[[ -e $sweep_root/clipboard/blobs/$future ]] || fail "future-dated orphan was removed"
if pgrep -f -- "$fixture_root" >/dev/null; then
    pgrep -af -- "$fixture_root" >&2
    fail "watcher processes outlived the shell"
fi
printf 'clipboard QML fixture ok\n'
