#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_root=$(cd -- "$script_dir/../.." && pwd)
repo_root=$(cd -- "$source_root/../../.." && pwd)
fixture_root=$(mktemp -d)

cleanup() {
  rm -rf -- "$fixture_root"
}
trap cleanup EXIT

export HOME="$fixture_root/home"
export XDG_CONFIG_HOME="$fixture_root/config"
export XDG_DATA_HOME="$fixture_root/data"
export XDG_STATE_HOME="$fixture_root/state"
export XDG_CACHE_HOME="$fixture_root/cache"
export XDG_RUNTIME_DIR="$fixture_root/runtime"
export QT_QPA_PLATFORM=offscreen
unset DBUS_SESSION_BUS_ADDRESS

mkdir -p "$HOME" "$XDG_CONFIG_HOME/quickshell" "$XDG_DATA_HOME" \
  "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

config_dir="$XDG_CONFIG_HOME/quickshell/stillsuit-power-resources-fixture"
mkdir -p "$config_dir"
cp -R -- "$source_root/." "$config_dir/"
cp -- "$script_dir/fixture-shell.qml" "$config_dir/shell.qml"

fixture_log="$fixture_root/quickshell.log"
quickshell --no-color -p "$config_dir" >"$fixture_log" 2>&1
if rg -n 'ERROR qml| ERROR:|POWER_RESOURCES_FIXTURE_FAIL' "$fixture_log"; then
  sed -n '1,240p' "$fixture_log" >&2
  exit 1
fi
grep -F 'POWER_RESOURCES_FIXTURE_OK checks=' "$fixture_log" >/dev/null

"$script_dir/battery-watcher.test.sh"

if rg -n '#[0-9a-fA-F]{6}|\.palette\.|theme\.colors|theme\.controls|theme\.geometry' \
    "$source_root/plugins/builtin/battery" \
    "$source_root/plugins/builtin/resources"; then
  printf 'power/resources UI bypasses the theme-v2 contract\n' >&2
  exit 1
fi

if rg -n 'notify-send|Battery critically low|BATTERY_THRESHOLD' \
    "$source_root/services/BatteryService.qml" \
    "$source_root/plugins/builtin/battery"; then
  printf 'Stillsuit owns battery alert policy\n' >&2
  exit 1
fi

rg -F 'interval: 3000' \
  "$source_root/plugins/builtin/resources/ResourceService.qml" >/dev/null
rg -F 'statFile.reload()' \
  "$source_root/plugins/builtin/resources/ResourceService.qml" >/dev/null
rg -F 'memoryFile.reload()' \
  "$source_root/plugins/builtin/resources/ResourceService.qml" >/dev/null
rg -F 'readonly property var detailHelperArgv: ["upower", "--dump"]' \
  "$source_root/services/BatteryService.qml" >/dev/null
rg -F 'interval: 15000' "$source_root/services/PowerService.qml" >/dev/null
if rg -n 'bash -lc|command:.*\+|command:.*\$\{' \
    "$source_root/services/BatteryService.qml" \
    "$source_root/services/PowerService.qml"; then
  printf 'power services contain a dynamic command\n' >&2
  exit 1
fi

module_json="$fixture_root/module.json"
nix eval --impure --json --expr '
  let
    flake = builtins.getFlake (toString '"$repo_root"');
    pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
    module = import '"$repo_root/home/services/battery-watcher.nix"' {
      config.dotfiles.services.battery-watcher.enable = true;
      inherit (pkgs) lib;
      inherit pkgs;
    };
  in {
    service = module.config.content.systemd.user.services.battery-watcher;
    timer = module.config.content.systemd.user.timers.battery-watcher;
  }
' >"$module_json"

jq -e '
  .service.Service.Type == "oneshot"
  and (.service.Service.ExecStart | contains("battery-watcher"))
  and .timer.Timer.OnUnitActiveSec == "1m"
  and .timer.Timer.RandomizedDelaySec == "5s"
  and (.timer.Install.WantedBy == ["graphical-session.target"])
' "$module_json" >/dev/null

printf 'power/resources fixture and systemd module contract ok\n'
