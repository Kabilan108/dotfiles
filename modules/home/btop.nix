{ config, lib, pkgs, ... }:
let
  btopWithRuntimeGpuLibraries = pkgs.symlinkJoin {
    name = "btop-with-runtime-gpu-libraries";
    paths = [ pkgs.btop ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/btop \
        --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib
    '';
  };
in
{
  stylix.targets.btop.enable = true;

  programs.btop = {
    enable = true;
    package = btopWithRuntimeGpuLibraries;
    settings = {
      theme_background = false;
    };
    themes.stylix =
      with config.lib.stylix.colors.withHashtag;
      lib.mkAfter ''
        theme[div_line]="${base04}"
      '';
  };
}
