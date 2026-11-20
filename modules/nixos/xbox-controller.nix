{ config, ... }:
{
  hardware.bluetooth.settings.General = {
    Privacy = "device";
    JustWorksRepairing = "always";
    Class = "0x000100";
    FastConnectable = true;
  };
  hardware.xpadneo.enable = true;
  boot.extraModulePackages = with config.boot.kernelPackages; [ xpadneo ];
  boot.extraModprobeConfig = ''
    options bluetooth disable_ertm=Y
  '';
}
