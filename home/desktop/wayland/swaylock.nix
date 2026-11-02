{
  config,
  lib,
  pkgs,
  ...
}:
let
  colors = config.lib.stylix.colors;
  # Dictator keeps its microphone open while the session is unlocked; release
  # it for the lock and resume it afterwards. Failures never block locking.
  dictatorEnabled = config.services.dictator.enable or false;
  dictatorMic =
    action:
    lib.optionalString dictatorEnabled ''
      ${pkgs.coreutils}/bin/timeout 3 ${lib.getExe config.services.dictator.package} mic ${action} >/dev/null 2>&1 || true
    '';
  lockScreen = pkgs.writeShellScriptBin "lock-screen" ''
    export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"

    if ${pkgs.procps}/bin/pidof swaylock >/dev/null; then
      exit 0
    fi

    if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
      for socket in "$XDG_RUNTIME_DIR"/wayland-*; do
        if [ -S "$socket" ]; then
          export WAYLAND_DISPLAY="''${socket##*/}"
          break
        fi
      done
    fi

    ${lib.optionalString dictatorEnabled "trap '${dictatorMic "resume"}' EXIT"}
    ${dictatorMic "release"}
    ${pkgs.swaylock-effects}/bin/swaylock "$@"
  '';
  lockscreenImage =
    if lib.hasPrefix "$HOME/" config.dotfiles.wallpaper.lockscreen then
      "${config.home.homeDirectory}/${lib.removePrefix "$HOME/" config.dotfiles.wallpaper.lockscreen}"
    else
      config.dotfiles.wallpaper.lockscreen;
in
{
  options.dotfiles.wallpaper.lockscreen = lib.mkOption {
    type = lib.types.str;
    description = "Path to the lock screen image.";
  };

  config = {
    programs.swaylock = {
      enable = true;
      package = pkgs.swaylock-effects;
    };

    home.packages = [ lockScreen ];

    xdg.configFile."swaylock/config".text = ''
      image=${lockscreenImage}
      fade-in=0

      clock
      timestr=%I:%M
      datestr=
      font=FiraMono Nerd Font
      font-size=28

      indicator
      indicator-radius=100
      indicator-thickness=8

      ring-color=${colors.base05}cc
      inside-color=${colors.base00}cc
      text-color=${colors.base05}
      line-color=00000000
      separator-color=00000000
      key-hl-color=${colors.base0B}
      bs-hl-color=${colors.base08}

      ring-ver-color=${colors.base0B}cc
      inside-ver-color=${colors.base00}cc
      text-ver-color=${colors.base05}

      ring-wrong-color=${colors.base08}cc
      inside-wrong-color=${colors.base00}cc
      text-wrong-color=${colors.base08}

      ring-clear-color=${colors.base0A}cc
      inside-clear-color=${colors.base00}cc
      text-clear-color=${colors.base05}

      show-failed-attempts
    '';
  };
}
