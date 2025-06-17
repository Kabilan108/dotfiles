{ pkgs, ... }:

let
  dictator =
    (builtins.getFlake "github:kabilan108/dictator").packages.${builtins.currentSystem}.default;
in
{
  environment.systemPackages = [ dictator ];

  systemd.user.services.dictator = {
    description = "Dictator voice typing daemon";
    documentation = [ "https://github.com/kabilan108/dictator" ];

    after = [ "graphical-session.target" ];
    wantedBy = [ "default.target" ];

    path = [
      pkgs.xdotool
      pkgs.xclip
      pkgs.portaudio
    ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${dictator}/bin/dictator daemon --log-level INFO";

      Restart = "on-failure";
      RestartSec = "5s";

      PassEnvironment = [
        "DISPLAY"
        "XAUTHORITY"
        "DBUS_SESSION_BUS_ADDRESS"
      ];
    };
  };
}
