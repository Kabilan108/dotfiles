# Every failed system unit posts to Hark (svc:hark on the tailnet) in the
# "Fleet" project. The webhook is a Hark service integration that only this
# host can decrypt (secrets.nix). Until that file exists the alerts are off.
# The message names the unit and its result, never log lines.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  defaultWebhookFile = ../../secrets/hark/tleilax-alerts.curl.age;
  webhookFile = config.dotfiles.alerts.webhookFile;

  sendAlert = pkgs.writeShellApplication {
    name = "fleet-alert";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      config.systemd.package
    ];
    text = ''
      unit=$1
      host=${config.networking.hostName}
      result=$(systemctl show --property=Result --value "$unit")
      status=$(systemctl show --property=ExecMainStatus --value "$unit")
      title="$host: $unit failed"
      body="Result: $result, exit status $status. Run journalctl -u $unit on $host."
      # One alert per unit per hour, however often it fails.
      key="fleet-alert:$host:$unit:$(date -u +%Y%m%dT%H)"
      jq -cn --arg title "$title" --arg body "$body" \
        '{title: $title, body: $body, project: "Fleet"}' |
        curl \
          --config "$CREDENTIALS_DIRECTORY/webhook" \
          --silent \
          --show-error \
          --fail \
          --retry 5 \
          --retry-all-errors \
          --retry-delay 15 \
          --output /dev/null \
          --header "Content-Type: application/json" \
          --header "Idempotency-Key: $key" \
          --data-binary @-
    '';
  };
in
{
  options.dotfiles.alerts.webhookFile = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    default = if builtins.pathExists defaultWebhookFile then defaultWebhookFile else null;
    defaultText = lib.literalMD "`secrets/hark/tleilax-alerts.curl.age`, once it exists";
    description = "agenix file holding the curl config (`url = \"...\"`) of the Hark webhook. Alerts are off while it is null.";
  };

  config = lib.mkIf (webhookFile != null) {
    age.secrets.hark-alerts = {
      file = webhookFile;
      mode = "0400";
    };

    systemd.services."fleet-alert@" = {
      description = "Tell Hark that %i failed";
      after = [
        "network-online.target"
        "tailscaled.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe sendAlert} %i";
        DynamicUser = true;
        LoadCredential = "webhook:${config.age.secrets.hark-alerts.path}";
      };
    };

    # Applies OnFailure= to every service. The alert unit's own drop-in sorts
    # later and clears it, so a failed alert doesn't alert.
    systemd.packages = [
      (pkgs.runCommand "fleet-alert-dropins" { } ''
        mkdir -p "$out/etc/systemd/system/service.d" "$out/etc/systemd/system/fleet-alert@.service.d"
        printf '[Unit]\nOnFailure=fleet-alert@%%n.service\n' \
          > "$out/etc/systemd/system/service.d/10-fleet-alert.conf"
        printf '[Unit]\nOnFailure=\n' \
          > "$out/etc/systemd/system/fleet-alert@.service.d/20-no-alert-loop.conf"
      '')
    ];
  };
}
