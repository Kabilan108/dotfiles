{ ... }:
{
  security.pam.services.i3lock.enable = true;

  services.displayManager.defaultSession = "none+i3";
  services.greenclip.enable = true;
  services.xserver = {
    enable = true;
    desktopManager.xterm.enable = false;
    windowManager.i3.enable = true;

    displayManager = {
      startx.enable = false;
      gdm.enable = true;
      gdm.wayland = false;
    };
    xkb = {
      layout = "us";
      variant = "";
    };
  };
}
