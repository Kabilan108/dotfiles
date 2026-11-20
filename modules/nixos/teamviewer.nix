{
  config,
  lib,
  pkgs,
  ...
}:
let
  teamviewer = pkgs.teamviewer.overrideAttrs (old: {
    postFixup = old.postFixup + ''
      wrapProgram $out/share/teamviewer/tv_bin/TeamViewer --set QT_QPA_PLATFORM xcb
    '';
  });
in
{
  config = lib.mkIf config.services.teamviewer.enable {
    services.teamviewer.package = lib.mkDefault teamviewer;

    systemd.services.teamviewerd.wantedBy = lib.mkForce [ ];
  };
}
