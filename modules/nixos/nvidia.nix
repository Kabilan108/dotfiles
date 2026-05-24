# Configure Nvidia drivers & CUDA

{ config, pkgs, ... }:
let
  fixedSecurityDriver = config.boot.kernelPackages.nvidiaPackages.mkDriver {
    version = "595.71.05";
    sha256_64bit = "sha256-NiA7iWC35JyKQva6H1hjzeNKBek9KyS3mK8G3YRva4I=";
    sha256_aarch64 = "sha256-XzKloS00dFKTd4ATWkTIhm9eG/OzR/Sim6MboNZWPu8=";
    openSha256 = "sha256-Lfz71QWKM6x/jD2B22SWpUi7/og30HRlXg1kL3EWzEw=";
    settingsSha256 = "sha256-mXnf3jyvznfB3OfKd657rxv0rYHQb/dX/Riw/+N9EKU=";
    persistencedSha256 = "sha256-Z/6IvEEa/XfZ5F5qoSIPvXJLGtscYVqjFxHZaN/M2Ts=";
  };
in
{
  # load driver for xorg & wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  # enable opengl
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = fixedSecurityDriver;
  };

  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    nvtopPackages.full
    nvidia-container-toolkit
  ];
}
