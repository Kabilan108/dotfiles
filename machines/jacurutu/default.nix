{ inputs, pkgs, ... }:
let
  spotifyAudioCacheBytes = 2 * 1000 * 1000 * 1000;
  bootPkgs = import inputs.jacurutu-boot-nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  imports = [
    ./framework.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "jacurutu";

  # Retain the boot stack from working generation 1141 while testing the
  # userspace graphics fix. The disk-unlock freeze had no persistent journal.
  boot.kernelPackages = bootPkgs.linuxPackages;
  nixpkgs.overlays = [
    (_final: _prev: { linux-firmware = bootPkgs.linux-firmware; })
  ];
  # External GUI flakes still use glibc 2.42 and cannot load the new Mesa.
  # Keep their working driver until those applications also use system pkgs.
  hardware.graphics = {
    package = bootPkgs.mesa;
    package32 = bootPkgs.pkgsi686Linux.mesa;
  };

  services.pipewire.wireplumber.extraConfig."50-mic-volume" = {
    "wireplumber.settings" = {
      "device.routes.default-source-volume" = 0.30;
    };
  };

  environment = {
    systemPackages = with pkgs; [ fprintd ];
  };

  home-manager.users.kabilan = {
    dotfiles.services = {
      codex-desktop.enable = true;
      dictator = {
        enable = true;
        activeProvider = "siren";
      };
      mic-volume-enforce.enable = true;
      parakeet-redux.enable = true;
      t3-code.enable = false;
      tracer-sync.enable = true;
    };

    programs.niri.config = null;
    services.spotifyd = {
      enable = true;
      settings.global = {
        autoplay = true;
        backend = "pulseaudio";
        bitrate = 320;
        cache_path = "/home/kabilan/.cache/spotifyd";
        dbus_type = "session";
        device_name = "jacurutu";
        device_type = "speaker";
        disable_discovery = true;
        max_cache_size = spotifyAudioCacheBytes;
        normalisation_pregain = 0.0;
        use_mpris = true;
        volume_normalisation = true;
      };
    };
    dotfiles.wallpaper.desktop = "$HOME/dotfiles/wallpapers/shoggoth-001.png";
    dotfiles.wallpaper.lockscreen = "$HOME/dotfiles/wallpapers/war-claude.png";
  };
}
