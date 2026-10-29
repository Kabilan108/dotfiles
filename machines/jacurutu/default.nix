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
  dotfiles.mobergTailscale.enable = true;

  # The Framework airplane key emits KEY_RFKILL directly to the kernel.
  # Disable its measured HID scan code without changing the other hotkeys.
  services.udev.extraHwdb = ''
    evdev:input:b0018v32ACp0006*
     KEYBOARD_KEY_100c6=reserved
  '';

  # Test the main package set's kernel for the security update. The earlier
  # disk-unlock freeze remains unresolved; retain generation 1141 for recovery.
  boot.kernelPackages = pkgs.linuxPackages;
  # Keep the working firmware from generation 1141 during the kernel boot test.
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
      solaar.enable = true;
      t3-code.enable = false;
      tracer-sync.enable = true;
    };

    # Desktop client only; T3 servers (sietch) run the native `t3` binary via t3-update.
    programs.appimages.apps.t3code = {
      repo = "pingdotgg/t3code";
      pattern = "T3-Code-*.AppImage";
      downloadPattern = "*x86_64.AppImage";
      desktopName = "T3 Code";
      comment = "T3 Code Editor";
      # Official Linux production icon, vendored from pingdotgg/t3code at
      # 69db400b3cd6b1590d0dfdabf9857621a9089b39.
      icon = "${../../config/t3code/icon.png}";
      args = [ "--password-store=gnome-libsecret" ];
      categories = [
        "Development"
        "TextEditor"
      ];
    };

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
    dotfiles.wallpaper.lockscreen = "$HOME/dotfiles/wallpapers/shoggoth-math-woodblock.png";
  };
}
