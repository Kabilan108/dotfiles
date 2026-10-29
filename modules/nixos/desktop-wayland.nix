{ inputs, pkgs, ... }:
{
  programs.gpu-screen-recorder.enable = true;

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [
    pkgs.xdg-desktop-portal-gtk
    # File chooser backend; niri routes to it in modules/home/scout.nix.
    pkgs.scout
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron/Chromium Wayland
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    # Send GTK file dialogs through the portal, so they open in scout.
    GDK_DEBUG = "portals"; # GTK 4 (and recent GTK 3)
    GTK_USE_PORTAL = "1"; # older GTK 3
  };

  environment.systemPackages = with pkgs; [
    wl-clipboard
    xdg-utils
  ];
}
