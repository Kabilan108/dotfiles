# Stillsuit Next human-owned gates

These gates are intentionally not executed by the migration orchestrator. Run
them from `/home/kabilan/dotfiles` on branch `stillsuit-next`. Gate 2 assumes
Gate 1 was accepted and remains applied.

## Gate 1: retire the agent workspace and Waybar

Applying the Niri patch changes the live, out-of-store configuration
immediately. The Waybar change takes effect only when the built generation is
activated.

```bash
set -euo pipefail
git apply --check docs/plans/staged-niri-workspace-removal.patch
git apply --unidiff-zero --check docs/plans/staged-waybar-disable.patch
git apply docs/plans/staged-niri-workspace-removal.patch
git apply --unidiff-zero docs/plans/staged-waybar-disable.patch
niri validate --config home/desktop/wayland/compositors/niri/config.kdl
nixfmt --check home/desktop/wayland/waybar.nix
nix flake check --no-build
sudo nixos-rebuild build --flake .#jacurutu
sudo ./result/bin/switch-to-configuration switch
if systemctl --user is-active --quiet waybar.service; then
  echo "Waybar is still active" >&2
  exit 1
fi
```

Rollback Gate 1 by restoring the working-tree files before building the
replacement generation:

```bash
set -euo pipefail
git apply --unidiff-zero -R docs/plans/staged-waybar-disable.patch
git apply -R docs/plans/staged-niri-workspace-removal.patch
niri validate --config home/desktop/wayland/compositors/niri/config.kdl
sudo nixos-rebuild build --flake .#jacurutu
sudo ./result/bin/switch-to-configuration switch
systemctl --user is-active waybar.service
```

## Gate 2: ordered Stillsuit cutover

First stage and build the cutover generation. This updates Niri's live binds
and startup declaration, but it does not stop the already-running legacy shell.

```bash
set -euo pipefail
git apply --unidiff-zero --check docs/plans/staged-stillsuit-cutover.patch
git apply --unidiff-zero docs/plans/staged-stillsuit-cutover.patch
niri validate --config home/desktop/wayland/compositors/niri/config.kdl
nixfmt --check home/desktop/wayland/quickshell/default.nix
nix flake check --no-build
sudo nixos-rebuild build --flake .#jacurutu
```

Then perform the single-owner handoff. The loops are bounded state checks, not
fixed replacement sleeps: the old PID must exit, the notification name must be
released, the new systemd PID must appear, and IPC must report ready.

```bash
set -euo pipefail

old_instances=$(qs list -c stillsuit --json)
old_pid=$(jq -er 'if length == 1 then .[0].pid else error("expected one legacy instance") end' <<<"$old_instances")

qs kill -c stillsuit
deadline=$((SECONDS + 15))
while kill -0 "$old_pid" 2>/dev/null; do
  (( SECONDS < deadline )) || {
    echo "legacy Stillsuit PID did not exit" >&2
    exit 1
  }
  sleep 0.05
done

deadline=$((SECONDS + 10))
while busctl --user status org.freedesktop.Notifications >/dev/null 2>&1; do
  (( SECONDS < deadline )) || {
    echo "notification D-Bus name was not released" >&2
    exit 1
  }
  sleep 0.05
done

sudo ./result/bin/switch-to-configuration switch

new_pid=0
deadline=$((SECONDS + 15))
while (( new_pid <= 0 )); do
  new_pid=$(systemctl --user show --property MainPID --value stillsuit-shell.service)
  (( SECONDS < deadline )) || {
    echo "stillsuit-shell.service did not acquire a PID" >&2
    exit 1
  }
  (( new_pid > 0 )) || sleep 0.05
done

ready=""
deadline=$((SECONDS + 15))
while [[ $ready != ok ]]; do
  ready=$(qs ipc -c stillsuit-next call stillsuit ping 2>/dev/null || true)
  (( SECONDS < deadline )) || {
    echo "Stillsuit IPC did not become ready" >&2
    exit 1
  }
  [[ $ready == ok ]] || sleep 0.05
done

systemctl --user is-active --quiet stillsuit-shell.service
busctl --user status org.freedesktop.Notifications >/dev/null
qs list -c stillsuit-next --json |
  jq -e --argjson pid "$new_pid" 'length == 1 and .[0].pid == $pid' >/dev/null
qs list -c stillsuit --json | jq -e 'length == 0' >/dev/null
qs ipc -c stillsuit-next call stillsuit status | jq -e '
  .ready == true
  and .bar.activeId == "stillsuit.bar"
  and .bar.state == "loaded"
  and ([.plugins | to_entries[] | select(.value.state == "error")] | length) == 0
' >/dev/null
```

If Gate 2 fails after activation, stop only the supervised Next unit, wait for
its exact PID and notification ownership to disappear, reverse the cutover
patch, switch back one system generation, and relaunch the legacy config:

```bash
set -euo pipefail
new_pid=$(systemctl --user show --property MainPID --value stillsuit-shell.service)
systemctl --user stop stillsuit-shell.service
deadline=$((SECONDS + 15))
while (( new_pid > 0 )) && kill -0 "$new_pid" 2>/dev/null; do
  (( SECONDS < deadline )) || {
    echo "Next Stillsuit PID did not exit" >&2
    exit 1
  }
  sleep 0.05
done
deadline=$((SECONDS + 10))
while busctl --user status org.freedesktop.Notifications >/dev/null 2>&1; do
  (( SECONDS < deadline )) || {
    echo "notification D-Bus name was not released" >&2
    exit 1
  }
  sleep 0.05
done

git apply --unidiff-zero -R docs/plans/staged-stillsuit-cutover.patch
niri validate --config home/desktop/wayland/compositors/niri/config.kdl
sudo nixos-rebuild switch --rollback
qs -c stillsuit --no-duplicate --daemonize

deadline=$((SECONDS + 15))
while ! qs list -c stillsuit --json | jq -e 'length == 1' >/dev/null; do
  (( SECONDS < deadline )) || {
    echo "legacy Stillsuit did not return" >&2
    exit 1
  }
  sleep 0.05
done
busctl --user status org.freedesktop.Notifications >/dev/null
```
