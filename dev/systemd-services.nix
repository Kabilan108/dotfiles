{ pkgs, inputs, ... }:
let
  dictator = inputs.dictator.packages.${pkgs.system}.default;
in
{
  home.packages = [ dictator ];

  systemd.user.services.dictator = {
    Unit = {
      Description = "Dictator voice typing daemon";
      Documentation = "https://github.com/kabilan108/dictator";
      After = "graphical-session.target";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${dictator}/bin/dictator daemon --log-level INFO";
      Restart = "on-failure";
      RestartSec = "5s";
      Environment = [
        "PATH=${
          pkgs.lib.makeBinPath [
            pkgs.xdotool
            pkgs.xclip
            pkgs.portaudio
          ]
        }"
      ];
      PassEnvironment = [
        "DISPLAY"
        "XAUTHORITY"
        "DBUS_SESSION_BUS_ADDRESS"
      ];
    };
  };
}
