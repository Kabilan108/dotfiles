{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.services.mic-volume-enforce;

  micEnforce = pkgs.writeShellScript "mic-volume-enforce" ''
    SOURCE="alsa_input.pci-0000_c1_00.6.analog-stereo"
    MAX=35

    ${pkgs.pulseaudio}/bin/pactl subscribe | while read -r line; do
      if [[ "$line" == *"'change' on source"* ]]; then
        vol=$(${pkgs.pulseaudio}/bin/pactl get-source-volume "$SOURCE" 2>/dev/null \
          | ${pkgs.gnugrep}/bin/grep -oP '\d+(?=%)' | head -1)
        if [[ -n "$vol" && "$vol" -gt "$MAX" ]]; then
          ${pkgs.pulseaudio}/bin/pactl set-source-volume "$SOURCE" 30%
        fi
      fi
    done
  '';
in
{
  options.dotfiles.services.mic-volume-enforce.enable = lib.mkEnableOption "internal mic volume cap";

  config = lib.mkIf cfg.enable {
    systemd.user.services.mic-volume-enforce = {
      Unit = {
        Description = "Enforce internal mic volume cap";
        After = [
          "pipewire.service"
          "wireplumber.service"
        ];
        Requires = [ "pipewire.service" ];
      };
      Service = {
        ExecStart = "${micEnforce}";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
