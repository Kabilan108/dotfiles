{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  runtimePkgs = import inputs.jacurutu-boot-nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  # The main package set's patched daemon crashes in the glibc loader.
  # Reuse the existing pinned input for its runtime.
  # Pinned to 15.83.3 for TV-2026-1011 (CVE-2026-111585, CVE-2026-92372) until
  # nixpkgs ships >= 15.83; then go back to `inherit (pkgs.teamviewer) version src`.
  teamviewer = runtimePkgs.teamviewer.overrideAttrs (old: {
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
