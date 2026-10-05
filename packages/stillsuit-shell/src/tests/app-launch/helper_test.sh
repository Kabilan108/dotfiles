#!/usr/bin/env bash
# Runs bin/stillsuit-app-launch against stub busctl, systemd-run, and
# notify-send commands and checks the systemd-run argv, unit name, working
# directory, environment, and the failure notifications.
# Checks are single-quoted so check() evaluates them after each run.
# shellcheck disable=SC2016,SC2034
set -euo pipefail

test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
helper=$(cd -- "$test_dir/../../.." && pwd)/bin/stillsuit-app-launch
work=$(mktemp -d /tmp/stillsuit-app-launch-helper.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT

stubs="$work/stubs"
record="$work/record"
session_bin="$work/session bin"
mkdir -p "$stubs" "$record" "$work/home" "$work/project dir" "$session_bin"
bash_bin=$(command -v bash)
cat_bin=$(command -v cat)
# Programs the session PATH resolves. A file named --help checks that an
# option-like program still resolves and stays after --.
for program in prog --help; do
    printf '#!%s\n' "$bash_bin" >"$session_bin/$program"
    chmod +x "$session_bin/$program"
done
touch "$session_bin/not-executable"

# The helper execs systemd-run under env -i, so the stub cannot rely on its
# environment to find the record directory or any tool.
cat >"$stubs/systemd-run" <<EOF
#!$bash_bin
printf '%s\0' "\$@" >"$record/argv"
printf '%s' "\$PWD" >"$record/cwd"
"$cat_bin" /proc/\$\$/environ >"$record/environ"
EOF
cat >"$stubs/busctl" <<EOF
#!$bash_bin
if [[ -e "$work/busctl-fails" ]]; then
    echo "busctl: connection refused" >&2
    exit 1
fi
printf '%s\n' "\$*" >"$record/busctl-args"
"$cat_bin" "$work/manager-environment.json"
EOF
cat >"$stubs/notify-send" <<EOF
#!$bash_bin
printf '%s\0' "\$@" >"$record/notify"
EOF
chmod +x "$stubs/systemd-run" "$stubs/busctl" "$stubs/notify-send"

# PATHs missing a tool: no systemd-run, a systemd-run that is not executable,
# and no env, so the exec itself fails.
partial_path() {
    local dir=$work/$1 tool
    shift
    mkdir -p "$dir"
    for tool in "$@"; do
        if [[ -e $stubs/$tool ]]; then
            ln -s "$stubs/$tool" "$dir/$tool"
        else
            ln -s "$(command -v "$tool")" "$dir/$tool"
        fi
    done
    printf '%s' "$dir"
}
no_systemd_run=$(partial_path no-systemd-run busctl notify-send jq env)
noexec_systemd_run=$(partial_path noexec-systemd-run busctl notify-send jq env)
touch "$noexec_systemd_run/systemd-run"
no_env=$(partial_path no-env busctl notify-send jq systemd-run)

jq -n --arg session_path "/nonexistent:$session_bin" '{type: "as", data: [
    "PATH=\($session_path)",
    "XDG_DATA_DIRS=/session/share:/usr/share",
    "HOME=/home/session",
    "EQUALS=a=b=c",
    "EMPTY=",
    "MULTI=line one\nline two",
    "SPACED=has  two  spaces",
    "1BAD=leading digit",
    "BAD-NAME=dash",
    "NOEQUALS",
    "=nameless"
]}' >"$work/manager-environment.json"

failures=0
checks=0
check() {
    checks=$((checks + 1))
    if ! eval "$1"; then
        printf 'FAIL: %s\n' "$2" >&2
        failures=$((failures + 1))
    fi
}

helper_path="$stubs:$PATH"
run_helper() {
    rm -f "${record:?}"/*
    set +e
    env -i HOME="$work/home" PATH="$helper_path" "$bash_bin" "$helper" "$@" \
        >"$work/stdout" 2>"$work/stderr"
    status=$?
    set -e
}

# A failed launch exits 1, starts nothing, and posts one notification that
# names the label and the reason but none of the program's argv.
expect_notified() {
    reason=$1
    check '[[ $status -eq 1 && ! -e $record/argv ]]' "failed launch exits 1 without systemd-run: $reason"
    notify=()
    if [[ -e $record/notify ]]; then mapfile -d '' -t notify <"$record/notify"; fi
    check '[[ ${#notify[@]} -eq 3 && ${notify[0]} == --app-name=Stillsuit && ${notify[1]} == "Couldn'"'"'t start Secret_App" && ${notify[2]} == "$reason" ]]' \
        "notification names the label and reason ($reason): ${notify[*]}"
    check '! grep -q SECRET "$record/notify"' "notification leaves out the argv ($reason)"
}

run_helper --check
check '[[ $status -eq 0 && ! -s $work/stdout && ! -s $work/stderr ]]' "--check exits 0 silently"
check '[[ ! -e $record/busctl-args && ! -e $record/argv && ! -e $record/notify ]]' \
    "--check touches no systemd tool"

recorded_argv() {
    mapfile -d '' -t argv <"$record/argv"
}

run_helper --name "Org.Gnome Files!" --cwd "$work/project dir" -- \
    prog "arg with  space" "" --flag
check '[[ $status -eq 0 ]]' "successful launch exits 0"
check '[[ ! -s $work/stdout && ! -s $work/stderr ]]' "successful launch prints nothing"
check '[[ ! -e $record/notify ]]' "successful launch posts no notification"
recorded_argv
check '[[ ${#argv[@]} -eq 11 ]]' "systemd-run receives 11 arguments (got ${#argv[@]})"
check '[[ ${argv[0]} == --user && ${argv[1]} == --scope && ${argv[2]} == --collect && ${argv[3]} == --quiet ]]' \
    "systemd-run runs a quiet, collected user scope"
check '[[ ${argv[4]} == --slice=app.slice ]]' "scope lands in app.slice"
check '[[ ${argv[5]} =~ ^--unit=app-stillsuit-Org\.Gnome_Files_-[0-9a-f]{8}\.scope$ ]]' \
    "unit name is sanitized with a random suffix (${argv[5]})"
check '[[ ${argv[6]} == -- && ${argv[7]} == prog && ${argv[8]} == "arg with  space" && ${argv[9]} == "" && ${argv[10]} == --flag ]]' \
    "program argv passes through unchanged after --"
check '[[ $(<"$record/cwd") == "$work/project dir" ]]' "existing --cwd becomes the working directory"
check '[[ $(<"$record/busctl-args") == "--user --json=short get-property org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager Environment" ]]' \
    "manager environment is read through busctl"
mapfile -d '' -t environment <"$record/environ"
expected=(
    "PATH=/nonexistent:$session_bin"
    "XDG_DATA_DIRS=/session/share:/usr/share"
    "HOME=/home/session"
    "EQUALS=a=b=c"
    "EMPTY="
    $'MULTI=line one\nline two'
    "SPACED=has  two  spaces"
)
check '[[ ${#environment[@]} -eq ${#expected[@]} ]]' \
    "environment holds exactly the valid manager entries (got ${#environment[@]})"
for entry in "${expected[@]}"; do
    found=0
    for actual in "${environment[@]}"; do
        [[ $actual == "$entry" ]] && found=1
    done
    check '[[ $found -eq 1 ]]' "environment carries ${entry%%=*}"
done

first_unit=${argv[5]}
run_helper --name "Org.Gnome Files!" -- prog
recorded_argv
check '[[ ${argv[5]} != "$first_unit" ]]' "each launch gets a fresh unit suffix"
check '[[ $(<"$record/cwd") == "$work/home" ]]' "missing --cwd falls back to HOME"

run_helper --name app --cwd "$work/does-not-exist" -- prog
check '[[ $(<"$record/cwd") == "$work/home" ]]' "nonexistent --cwd falls back to HOME"

(cd "$work" && run_helper --name app --cwd "project dir" -- prog)
check '[[ $(<"$record/cwd") == "$work/home" ]]' "relative --cwd falls back to HOME"

run_helper --name '!!!' -- prog
recorded_argv
check '[[ ${argv[5]} =~ ^--unit=app-stillsuit-app-[0-9a-f]{8}\.scope$ ]]' \
    "a label without alphanumerics collapses to app (${argv[5]})"

run_helper --name '' -- prog
recorded_argv
check '[[ ${argv[5]} =~ ^--unit=app-stillsuit-app-[0-9a-f]{8}\.scope$ ]]' "an empty label collapses to app"

run_helper --name "$(printf 'x%.0s' {1..100})" -- prog
recorded_argv
check '[[ ${argv[5]} =~ ^--unit=app-stillsuit-x{64}-[0-9a-f]{8}\.scope$ ]]' "labels are capped at 64 characters"

run_helper --name 'google-chrome' -- prog
recorded_argv
check '[[ ${argv[5]} =~ ^--unit=app-stillsuit-google-chrome-[0-9a-f]{8}\.scope$ ]]' "dashes are kept"

run_helper --name app -- --help
recorded_argv
check '[[ ${argv[6]} == -- && ${argv[7]} == --help ]]' "an option-like program stays after --"

refuse() {
    run_helper "$@"
    check '[[ $status -eq 2 && ! -e $record/argv ]]' "refuses: $*"
}
refuse --name app prog
refuse --name app
refuse --name app --
refuse --name app -- ""
refuse --name
refuse --cwd
refuse --unknown -- prog
refuse

check '[[ ! -e $record/notify ]]' "usage errors post no notification"

run_helper --name "Secret App" -- missing-program SECRET-ARG
expect_notified "Its program was not found."
run_helper --name "Secret App" -- "$session_bin/missing" SECRET-ARG
expect_notified "Its program was not found."
run_helper --name "Secret App" -- not-executable SECRET-ARG
expect_notified "Its program was not found."
run_helper --name "Secret App" -- "$session_bin/prog" SECRET-ARG
check '[[ $status -eq 0 && -e $record/argv && ! -e $record/notify ]]' "an absolute program path resolves"

helper_path=$no_systemd_run
run_helper --name "Secret App" -- prog SECRET-ARG
expect_notified "systemd-run is not available."
helper_path=$noexec_systemd_run
run_helper --name "Secret App" -- prog SECRET-ARG
expect_notified "systemd-run is not available."
helper_path=$no_env
run_helper --name "Secret App" -- prog SECRET-ARG
expect_notified "systemd-run could not be started."
helper_path="$stubs:$PATH"

touch "$work/busctl-fails"
run_helper --name "Secret App" -- prog SECRET-ARG
expect_notified "The session environment is unavailable."
rm "$work/busctl-fails"

printf '%s\n' '{"type":"s","data":"PATH=/x"}' >"$work/manager-environment.json"
run_helper --name "Secret App" -- prog SECRET-ARG
expect_notified "The session environment is unreadable."

printf '%s\n' '{"type":"as","data":["PATH=/x",{"NAME":"value"}]}' >"$work/manager-environment.json"
run_helper --name "Secret App" -- prog SECRET-ARG
expect_notified "The session environment is unreadable."

if ((failures > 0)); then
    printf 'app-launch helper: %d of %d checks failed\n' "$failures" "$checks" >&2
    exit 1
fi
printf 'app-launch helper ok: %d checks\n' "$checks"
