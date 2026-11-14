# shellcheck shell=bash
# Print the name of the deploy key (~/.ssh/NAME) whose YubiKey is plugged in.
#
#   deploy-key
#
# DEPLOY_KEY_SERIALS maps YubiKey serials to key names, as
# "SERIAL=NAME SERIAL=NAME". With exactly one of those YubiKeys plugged in it
# prints that key's name. With more than one it prints DEPLOY_DEFAULT_KEY.
# With none it explains what to plug in and exits 1. If ykman is missing or
# can't read the YubiKeys, it warns and prints DEPLOY_DEFAULT_KEY. Messages go
# to stderr.
#
# `ykman list` reads each key's serial over PC/SC or USB HID without a PIN or
# a touch. Without pcscd it still reads them over the FIDO HID interface,
# which signing already needs.
set -euo pipefail

: "${DEPLOY_KEY_SERIALS:?}" "${DEPLOY_DEFAULT_KEY:?}"

declare -A key_of
for pair in $DEPLOY_KEY_SERIALS; do
  key_of[${pair%%=*}]=${pair#*=}
done

fall_back() {
  echo "deploy-key: $1; signing with $DEPLOY_DEFAULT_KEY." >&2
  echo "$DEPLOY_DEFAULT_KEY"
  exit 0
}

command -v ykman >/dev/null || fall_back "ykman isn't installed, so it can't tell which YubiKey is plugged in"
# ykman logs each transport that fails to stderr, even when another one reads
# the key, so only its exit status counts.
status=0
listing=$(ykman list 2>/dev/null) || status=$?
((status == 0)) || fall_back "ykman list failed (exit $status)"

found=() others=()
while IFS= read -r line; do
  [[ -n $line ]] || continue
  if [[ $line == *"<access denied>"* ]]; then
    fall_back "ykman can't open a plugged-in YubiKey ($line)"
  fi
  if [[ $line =~ \ Serial:\ ([0-9]+)$ && -n ${key_of[${BASH_REMATCH[1]}]:-} ]]; then
    found+=("${key_of[${BASH_REMATCH[1]}]}")
  else
    others+=("$line")
  fi
done <<<"$listing"

case ${#found[@]} in
1)
  echo "deploy-key: signing with ${found[0]}, the deploy key on the plugged-in YubiKey." >&2
  echo "${found[0]}"
  ;;
0)
  {
    echo "deploy-key: no deploy YubiKey is plugged in."
    if ((${#others[@]})); then
      echo "These YubiKeys hold no deploy key:"
      printf '  %s\n' "${others[@]}"
    fi
    echo "Plug in one of these, or pass --key:"
    for pair in $DEPLOY_KEY_SERIALS; do
      echo "  serial ${pair%%=*} for ${pair#*=}"
    done
  } >&2
  exit 1
  ;;
*)
  printf -v names '%s, ' "${found[@]}"
  echo "deploy-key: more than one deploy YubiKey is plugged in (${names%, }); signing with the default, $DEPLOY_DEFAULT_KEY." >&2
  echo "$DEPLOY_DEFAULT_KEY"
  ;;
esac
