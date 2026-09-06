#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../../../../.." && pwd)
test_root=$(mktemp -d)

cleanup() {
  rm -rf -- "$test_root"
}
trap cleanup EXIT

battery_path="$test_root/power/BAT0"
state_file="$test_root/state/battery-watcher/state"
notify_log="$test_root/notifications.log"
mkdir -p -- "$battery_path"
: >"$notify_log"

run_check() {
  local capacity=$1
  local status=$2

  printf '%s\n' "$capacity" >"$battery_path/capacity"
  printf '%s\n' "$status" >"$battery_path/status"
  BATTERY_PATH="$battery_path" \
    BATTERY_STATE_FILE="$state_file" \
    BATTERY_NOTIFY_BIN="$script_dir/fake-notify" \
    BATTERY_NOTIFY_LOG="$notify_log" \
    "$repo_root/bin/battery-watcher"
}

notification_count() {
  wc -l <"$notify_log"
}

run_check 19 Discharging
[[ $(notification_count) -eq 1 ]]
grep -F "Low battery 19% remaining" "$notify_log" >/dev/null

run_check 18 Discharging
[[ $(notification_count) -eq 1 ]]

run_check 5 Discharging
[[ $(notification_count) -eq 2 ]]
grep -F "Battery critically low 5% remaining. Plug in now." "$notify_log" >/dev/null

run_check 4 Discharging
[[ $(notification_count) -eq 2 ]]

run_check 9 Charging
run_check 5 Discharging
[[ $(notification_count) -eq 3 ]]

run_check 24 Charging
run_check 20 Discharging
[[ $(notification_count) -eq 4 ]]

run_check 95 Charging
[[ $(notification_count) -eq 5 ]]
grep -F "Battery charged 95%" "$notify_log" >/dev/null

run_check 96 Charging
[[ $(notification_count) -eq 5 ]]
run_check 91 Charging
run_check 95 "Not charging"
[[ $(notification_count) -eq 6 ]]

run_check invalid Discharging
[[ $(notification_count) -eq 6 ]]

grep -E '^low_armed=[01]$' "$state_file" >/dev/null
grep -E '^critical_armed=[01]$' "$state_file" >/dev/null
grep -E '^full_armed=[01]$' "$state_file" >/dev/null

printf 'battery watcher thresholds, dedupe, and hysteresis ok\n'
