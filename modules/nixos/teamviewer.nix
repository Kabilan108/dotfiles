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
  # Reuse the existing pinned input for its runtime, keeping the current release.
  teamviewer = runtimePkgs.teamviewer.overrideAttrs (old: {
    inherit (pkgs.teamviewer) version src;
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
