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
    runtimeEnv.FLEET_ALERT_EXCLUDE = lib.concatStringsSep " " config.dotfiles.alerts.exclude;
    text = ''
      unit=$1
      host=${config.networking.hostName}
      case " $FLEET_ALERT_EXCLUDE " in
        *" $unit "*)
          echo "fleet-alert: $unit alerts on its own"
          exit 0
          ;;
      esac
      case "$unit" in
        fleet-alert@*)
          echo "fleet-alert: not alerting about a failed alert, $unit"
          exit 0
          ;;
      esac
      result=$(systemctl show --property=Result --value "$unit")
      status=$(systemctl show --property=ExecMainStatus --value "$unit")
      title="$host: $unit failed"
      body="Result: $result, exit status $status. Run journalctl -u $unit on $host."
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
  options.dotfiles.alerts = {
    webhookFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = if builtins.pathExists defaultWebhookFile then defaultWebhookFile else null;
      defaultText = lib.literalMD "`secrets/hark/tleilax-alerts.curl.age`, once it exists";
      description = "agenix file holding the curl config (`url = \"...\"`) of the Hark webhook. Alerts are off while it is null.";
    };
    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "restic-backups-executor.service" ];
      description = "Units that alert on their own terms, such as after their retries, so a failure doesn't also send this generic alert.";
    };
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

    systemd.packages = [
      (pkgs.runCommand "fleet-alert-dropins" { } ''
        mkdir -p "$out/etc/systemd/system/service.d"
        printf '[Unit]\nOnFailure=fleet-alert@%%n.service\n' \
          > "$out/etc/systemd/system/service.d/10-fleet-alert.conf"
      '')
    ];
  };
}
