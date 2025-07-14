# Configure Nvidia drivers & CUDA

{ config, pkgs, ... }:
{
  # load driver for xorg & wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  # enable opengl
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;

  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    nvtopPackages.full
    nvidia-container-toolkit
  ];
}
