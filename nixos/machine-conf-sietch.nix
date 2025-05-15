{
  machineProfile = "workstation-sietch";
  hostName = "sietch";
  enableNvidia = true;
  env = rec {
    WALLPAPER = "$HOME/media/wallpapers/evangelion-eva-1.png";
  };
}
