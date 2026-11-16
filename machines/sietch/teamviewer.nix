{
  config,
  lib,
  pkgs,
  ...
}:
let
  # The pinned package stays the NixOS module's package. This wrapper only
  # shadows the launcher, the desktop entries, and the session service that
  # opens the GUI. teamviewerd itself is unchanged.
  launcher = pkgs.writeShellApplication {
    name = "teamviewer";
    runtimeInputs = [
      pkgs.systemd
      pkgs.util-linux
    ];
    text = ''
      export TEAMVIEWER_BIN=${lib.escapeShellArg "${config.services.teamviewer.package}/bin/teamviewer"}
    ''
    + builtins.readFile ./teamviewer-on-demand.sh;
  };
  launcherBin = lib.getExe launcher;
  onDemand = pkgs.symlinkJoin {
    name = "teamviewer-on-demand";
    paths = [
      launcher
      (pkgs.writeTextDir "share/applications/com.teamviewer.TeamViewer.desktop" ''
        [Desktop Entry]
        Version=1.0
        Type=Application
        Categories=Network;
        Name=TeamViewer
        Comment=Remote control solution.
        Exec=${launcherBin}
        Icon=TeamViewer
      '')
      (pkgs.writeTextDir "share/applications/teamvieweruri.desktop" ''
        [Desktop Entry]
        Type=Application
        Name=TeamViewer
        Exec=${launcherBin} --url "%u"
        NoDisplay=true
        StartupNotify=false
        MimeType=x-scheme-handler/teamviewer8;x-scheme-handler/teamviewer10;x-scheme-handler/teamviewerapi;x-scheme-handler/tvoneweblogin;
      '')
      (pkgs.writeTextDir "share/dbus-1/services/com.teamviewer.TeamViewer.service" ''
        [D-BUS Service]
        Name=com.teamviewer.TeamViewer
        Exec=${launcherBin} --minimize
      '')
    ];
  };
in
{
  # jacurutu still uses the NixOS module default and starts teamviewerd with
  # multi-user.target. Sietch only places outgoing connections, so the root
  # daemon stays down until the app is opened.
  config = lib.mkIf config.services.teamviewer.enable {
    systemd.services.teamviewerd.wantedBy = lib.mkForce [ ];

    # systemd authorizes start/stop through org.freedesktop.systemd1.manage-units
    # and passes the canonical unit id plus the verb. It does not pass job
    # mode, so this grant also covers a non-default job mode on this one unit.
    # enable/disable is a different action and stays locked.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (
          action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "teamviewerd.service" &&
          subject.user == "kabilan"
        ) {
          var verb = action.lookup("verb");
          if (verb == "start" || verb == "stop") {
            return polkit.Result.YES;
          }
        }
      });
    '';

    # Higher priority (lower number) wins buildEnv collisions, so `teamviewer`
    # and the upstream desktop/dbus names resolve to the wrapper.
    environment.systemPackages = [ (lib.hiPrio onDemand) ];
  };
}
