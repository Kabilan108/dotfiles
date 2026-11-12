{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Pinned to 15.83.3 for TV-2026-1011 (CVE-2026-111585, CVE-2026-92372) until
  # nixpkgs ships >= 15.83; then go back to `inherit (pkgs.teamviewer) version src`.
  teamviewer = pkgs.teamviewer.overrideAttrs (old: {
    version = "15.83.3";
    src = pkgs.fetchurl {
      url = "https://dl.teamviewer.com/download/linux/version_15x/teamviewer_15.83.3_amd64.deb";
      hash = "sha256-8xMNJO2+JZ71ukalQ8bVqCOuoqFPUzg08uSEv9ymiQk=";
    };
    postFixup = old.postFixup + ''
      wrapProgram $out/share/teamviewer/tv_bin/TeamViewer --set QT_QPA_PLATFORM xcb
    '';
  });
in
{
  config = lib.mkIf config.services.teamviewer.enable {
    services.teamviewer.package = lib.mkDefault teamviewer;
  };
}
