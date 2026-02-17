{ pkgs, ... }:
let
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
  imports = [
    ./framework.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "jacurutu";

  services.pipewire.wireplumber.extraConfig."50-mic-volume" = {
    "wireplumber.settings" = {
      "device.routes.default-source-volume" = 0.30;
    };
  };

  environment = {
    systemPackages = with pkgs; [ fprintd ];
  };

  home-manager.users.kabilan = {
    programs.niri.config = null;
    wallpaper.desktop = "$HOME/dotfiles/wallpapers/witcher.png";
    wallpaper.lockscreen = "$HOME/dotfiles/wallpapers/witcher.png";

    systemd.user.services.mic-volume-enforce = {
      Unit = {
        Description = "Enforce internal mic volume cap";
        After = [ "pipewire.service" "wireplumber.service" ];
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
