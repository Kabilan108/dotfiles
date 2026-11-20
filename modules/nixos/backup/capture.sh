# shellcheck shell=bash

stage="$1"
spec="$2"

rm -rf -- "$stage"
install -d -m 0711 -o root -g root "$stage"

while IFS=$'\t' read -r name user database; do
  [ -n "$name" ] || continue
  uid="$(id -u "$user" 2>/dev/null || printf '%s' "$user")"
  gid="$(id -g "$user" 2>/dev/null || printf '%s' "$user")"
  dir="$stage/$name"
  copy="$dir/$(basename "$database")"
  install -d -m 0700 -o "$uid" -g "$gid" "$dir"

  as_owner() {
    setpriv --reuid="$uid" --regid="$gid" --clear-groups -- "$@"
  }

  if [ ! -f "$database" ]; then
    echo "backup-capture: $name: $database does not exist" >&2
    exit 1
  fi
  as_owner sqlite3 -init /dev/null -bail "$database" ".backup '$copy'"
  as_owner sqlite3 -init /dev/null -bail "$copy" 'PRAGMA journal_mode=DELETE;' > /dev/null
  result="$(as_owner sqlite3 -init /dev/null -readonly "$copy" 'PRAGMA quick_check;')"
  if [ "$result" != ok ]; then
    echo "backup-capture: $name: quick_check on the copy said: $result" >&2
    exit 1
  fi
  echo "backup-capture: $name: copied $database"
done < "$spec"
