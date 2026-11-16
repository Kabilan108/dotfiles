# shellcheck shell=bash

# GUI launches start teamviewerd for this process and stop it on the way out.
# `teamviewer daemon` and the other management subcommands are passed through
# so they do not take the session lock or stop a GUI that is already up.
#
# shellcheck disable=SC2154 # TEAMVIEWER_BIN is exported by the Nix wrapper
real="${TEAMVIEWER_BIN:?}"

action="${1-}"
action="${action#-}"
action="${action#-}"

case "$action" in
help | version | info | ziplog | license | passwd | password | daemon | \
  extended-input | setup | assignment | unassign | repo | repository | \
  uninstall | ps | pstree | psfuzzy | pulseinfo | export-license | net)
  exec "$real" "$@"
  ;;
esac

# Every GUI launch brings the daemon up. Only the lock holder stops it, so a
# second launch cannot tear it down under the session that owns it. With no
# per-user runtime dir there is nowhere safe to put that lock, so leave the
# daemon running.
systemctl start teamviewerd.service

lockdir="${XDG_RUNTIME_DIR-}"
if [[ -z "$lockdir" || ! -d "$lockdir" ]]; then
  exec "$real" "$@"
fi

exec 9>"$lockdir/teamviewerd-app.lock"
if ! flock -n 9; then
  exec "$real" "$@"
fi

# A function, not an inline trap string: ShellCheck does not treat assignments
# inside a trap string as assignments, and the trap must keep the app's status.
stop_teamviewerd() {
  local status=$?
  systemctl stop teamviewerd.service || true
  exit "$status"
}
trap stop_teamviewerd EXIT
"$real" "$@"
