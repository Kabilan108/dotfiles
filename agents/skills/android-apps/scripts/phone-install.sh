#!/usr/bin/env bash
# Usage: phone-install.sh HOST APK PACKAGE ACTIVITY
# ACTIVITY is a full class name or one relative to PACKAGE, e.g. .MainActivity.
# Needs wireless debugging on and this machine paired. Exits 0 only when the app
# was installed over the existing one, is running, and the crash log is empty.
set -u
usage="usage: phone-install.sh HOST APK PACKAGE ACTIVITY"
host=${1:?$usage}
apk=${2:?$usage}
pkg=${3:?$usage}
activity=${4:?$usage}
here=$(cd "$(dirname "$0")" && pwd)
[[ -f $apk ]] || { echo "no such APK: $apk" >&2; exit 2; }

for port in $(python3 "$here/adb-scan.py" "$host"); do
  serial=$host:$port
  timeout 15 adb connect "$serial" >/dev/null 2>&1
  state=$(timeout 5 adb -s "$serial" get-state 2>&1)
  if [[ $state == device ]]; then
    echo "connected $serial"
    adb -s "$serial" install -r "$apk" || exit 1
    adb -s "$serial" shell dumpsys package "$pkg" | grep -E "versionName|versionCode|lastUpdateTime"
    adb -s "$serial" logcat -c
    adb -s "$serial" shell am start -W -n "$pkg/$activity" || exit 1
    sleep 6
    pid=$(adb -s "$serial" shell pidof "$pkg")
    crashes=$(adb -s "$serial" logcat -d -b crash)
    echo "pid=${pid:-none}"
    [[ -z $crashes ]] || printf -- '--- crash log\n%s\n' "$crashes"
    [[ -n $pid && -z $crashes ]] || exit 3
    echo "installed and launched"
    exit 0
  fi
  [[ $state == *unauthorized* ]] && echo "$serial is unauthorized: pairing may be lost" >&2
  adb disconnect "$serial" >/dev/null 2>&1
done
echo "no wireless-debugging port answered on $host" >&2
exit 4
