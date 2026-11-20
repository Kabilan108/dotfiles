# shellcheck shell=bash
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
