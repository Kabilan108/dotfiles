# shellcheck shell=bash
# shellcheck disable=SC2154 # run.sh sets $out and resolved.sh sets $python

total_passes=0
failures=()
section_name=
section_passes=0
section_fails=0
section_results=()

pass() {
  total_passes=$((total_passes + 1))
  section_passes=$((section_passes + 1))
  echo "PASS $*"
}

fail() {
  failures+=("$section_name: $*")
  section_fails=$((section_fails + 1))
  echo "FAIL $*"
}

check() {
  local label=$1
  shift
  if "$@"; then pass "$label"; else fail "$label"; fi
}

end_section() {
  [[ -n $section_name ]] || return 0
  section_results+=("$section_name: $section_passes passed, $section_fails failed")
  section_name=
}

section() {
  end_section
  section_name=$1
  section_passes=0
  section_fails=0
  printf '\n== %s\n' "$1"
}

expect_http() {
  local expected=$1 label=$2 code
  shift 2
  code=$(curl -s --path-as-is -o "$out/body" -w '%{http_code}' --max-time 10 "$@")
  if [[ " $expected " == *" $code "* ]]; then
    pass "[$code] $label"
  else
    fail "[$code, want $expected] $label :: $(head -c 200 "$out/body" | tr '\n' ' ')"
  fi
}

body_has() { grep -q -- "$1" "$out/body"; }
body_lacks() { ! grep -q -- "$1" "$out/body"; }

wait_http() {
  local _
  for _ in $(seq 1 300); do
    curl -s -o /dev/null --max-time 1 "$1" && return 0
    sleep 0.1
  done
  return 1
}

free_ports() {
  "$python" -I -c '
import socket, sys
socks = [socket.socket() for _ in range(int(sys.argv[1]))]
for s in socks:
    s.bind(("127.0.0.1", 0))
print(" ".join(str(s.getsockname()[1]) for s in socks))
' "$1"
}

stop_pid() {
  [[ -n ${1:-} ]] || return 0
  kill "$1" 2>/dev/null
  wait "$1" 2>/dev/null
  return 0
}

has_main_log() {
  [[ -e $1/logs/main.log || -e $1/auth/logs/main.log ]]
}

no_main_log() { ! has_main_log "$1"; }

only_error_logs() {
  local file
  for file in "$1"/logs/* "$1"/logs/.[!.]* "$1"/auth/logs/* "$1"/auth/logs/.[!.]*; do
    [[ -e $file ]] || continue
    if [[ $(basename "$file") != error-*.log ]]; then
      echo "unexpected log file: $file"
      return 1
    fi
    echo "request error log: $file"
  done
}
