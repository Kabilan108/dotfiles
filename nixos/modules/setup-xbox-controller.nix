# Configure XBox Controller

{ config, ... }:
{
  hardware.bluetooth.settings.General = {
    experimental = true; # show battery
    # for pairing controller: https://www.reddit.com/r/NixOS/comments/1ch5d2p/comment/lkbabax/
    Privacy = "device";
    JustWorksRepairing = "always";
    Class = "0x000100";
    FastConnectable = true;
  };
  hardware.xpadneo.enable = true; # for Xbox One controller
  boot.extraModulePackages = with config.boot.kernelPackages; [ xpadneo ];
  boot.extraModprobeConfig = ''
    options bluetooth disable_ertm=Y
  '';
}
