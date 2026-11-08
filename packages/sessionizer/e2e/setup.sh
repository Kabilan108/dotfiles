#!/usr/bin/env bash
# Usage: setup.sh BINARY FIXTURE_DIR
# Builds a three-server fixture in FIXTURE_DIR: driver (the terminal), local
# (the origin host), remote (a fleet host reached through a fake ssh).
set -euo pipefail
BIN=$1
F=$2
S=$(mktemp -d /tmp/sz.XXXXXX)
mkdir -p "$F" "$S"/{l,r,d}
ln -s "$S/l" "$F/local-tmux-s"; ln -s "$S/r" "$F/remote-tmux-s"; ln -s "$S/d" "$F/driver-tmux-s"
echo "$S" > "$F/sockdir"
mkdir -p "$F"/{fakebin,local-home/.ssh,local-home/bin,local-home/.config/fleet,local-home/.config/sessionizer,local-home/repos/alpha,local-home/repos/gamma}
mkdir -p "$F"/{remote-home/bin,remote-home/repos/rdir,remote-home/repos/rdir2,remote-home/.config/sessionizer,local-run,remote-run}
chmod 700 "$F"/local-run "$F"/remote-run
HOST=$(hostname -s)
touch "$F/local-home/.ssh/agent-$HOST"
ln -s "$BIN" "$F/local-home/bin/sessionizer"
ln -s "$BIN" "$F/remote-home/bin/sessionizer"
printf 'fakeremote\t#cba6f7\t127.0.0.1\n' > "$F/local-home/.config/fleet/hosts"
printf '{"search_paths":["~/repos"],"max_depth":1,"ignore":[],"remote_hosts":["fakeremote"]}\n' > "$F/local-home/.config/sessionizer/config.json"
printf '{"search_paths":["~/repos"],"max_depth":1,"ignore":[],"remote_hosts":[]}\n' > "$F/remote-home/.config/sessionizer/config.json"

cat > "$F/fakebin/ssh" <<EOF
#!/usr/bin/env bash
# Fake ssh: logs its arguments and runs the command against the remote fixture.
printf '%s\n' "\$*" >> "$F/ssh.log"
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o|-O|-i|-p) shift 2 ;;
    -*) shift ;;
    *) break ;;
  esac
done
host=\$1; shift
[ -n "\${FAKE_SSH_DOWN:-}" ] && { echo "ssh: connect to host \$host: refused" >&2; exit 255; }
exec env -u TMUX -u TMUX_PANE HOME="$F/remote-home" TMUX_TMPDIR="$S/r" XDG_RUNTIME_DIR="$F/remote-run" \
  XDG_CONFIG_HOME="$F/remote-home/.config" XDG_CACHE_HOME="$F/remote-home/.cache" XDG_STATE_HOME="$F/remote-home/.state" \
  sh -c "\$*"
EOF
chmod +x "$F/fakebin/ssh"

cat > "$F/local.conf" <<EOF
set -g prefix C-a
set -g detach-on-destroy off
set -g default-terminal tmux-256color
bind -n M-s display-popup -w 80% -h 70% -E "\$HOME/bin/sessionizer"
bind -T sessionizer-proxy M-s display-popup -w 80% -h 70% -E "\$HOME/bin/sessionizer"
EOF
cat > "$F/remote.conf" <<EOF
set -g prefix C-a
bind C-a send-prefix
set -g detach-on-destroy off
set -g status-left '[REMOTE #S] '
bind -n M-s run-shell "touch $F/remote-saw-ms"
EOF
cat > "$F/env.sh" <<EOF
F=$F
S=$S
L() { env -u TMUX HOME=\$F/local-home TMUX_TMPDIR=\$S/l XDG_RUNTIME_DIR=\$F/local-run XDG_CONFIG_HOME=\$F/local-home/.config XDG_CACHE_HOME=\$F/local-home/.cache XDG_STATE_HOME=\$F/local-home/.state PATH=\$F/fakebin:\$PATH tmux -f \$F/local.conf "\$@"; }
R() { env -u TMUX HOME=\$F/remote-home TMUX_TMPDIR=\$S/r tmux -f \$F/remote.conf "\$@"; }
D() { env -u TMUX TMUX_TMPDIR=\$S/d tmux -f /dev/null "\$@"; }
screen() { D capture-pane -p -t drv; }
client() { L list-clients -F '#{client_name}' | head -1; }
key() { L send-keys -c "\$(client)" -K "\$@"; }
waitfor() { local i; for i in \$(seq 1 50); do if eval "\$1" >/dev/null 2>&1; then return 0; fi; sleep 0.1; done; echo "TIMEOUT: \$1" >&2; screen >&2; return 1; }
EOF
. "$F/env.sh"
R new-session -d -s r-one -c "$F/remote-home"
R new-session -d -s r-two -c "$F/remote-home"
L new-session -d -s alpha -c "$F/local-home/repos/alpha"
L new-session -d -s beta -c "$F/local-home"
D new-session -d -s drv -x 150 -y 45 "env -u TMUX HOME=$F/local-home TMUX_TMPDIR=$S/l tmux attach -t alpha"
waitfor '[ -n "$(client)" ]'
echo "fixture ready at $F"
