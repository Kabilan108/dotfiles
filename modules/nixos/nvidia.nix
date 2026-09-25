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
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.docker.daemon.settings.features.cdi = true;

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  # The driver's heap-reuse heuristic keeps ~1 GiB of freed buffers pooled in
  # niri instead of ~100 MiB. https://yalter.github.io/niri/Nvidia.html
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
    builtins.toJSON {
      rules = [
        {
          pattern = {
            feature = "procname";
            matches = "niri";
          };
          profile = "Limit Free Buffer Pool On Wayland Compositors";
        }
      ];
      profiles = [
        {
          name = "Limit Free Buffer Pool On Wayland Compositors";
          settings = [
            {
              key = "GLVidHeapReuseRatio";
              value = 0;
            }
          ];
        }
      ];
    };

  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    nvtopPackages.full
    nvidia-container-toolkit
  ];
}
