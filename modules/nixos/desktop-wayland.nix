{ pkgs, ... }:
{
  programs.gpu-screen-recorder.enable = true;

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [
    pkgs.xdg-desktop-portal-gtk
    pkgs.scout
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    GDK_DEBUG = "portals";
    GTK_USE_PORTAL = "1";
  };

  environment.systemPackages = with pkgs; [
    wl-clipboard
    xdg-utils
  ];
}
