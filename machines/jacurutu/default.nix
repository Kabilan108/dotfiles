{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  fleet = import ../../lib/fleet.nix;
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

  services.teamviewer.enable = true;

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
    (_final: _prev: { inherit (bootPkgs) linux-firmware; })
    inputs.spindle.overlays.default
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

  # The YubiKeys' age identities (PIV) go through pcscd. agenix finds
  # age-plugin-yubikey on PATH when a recipient is an age1yubikey1... key.
  services.pcscd.enable = true;

  environment = {
    systemPackages = with pkgs; [
      age-plugin-yubikey
      fprintd
    ];
  };

  # docs/backups.md
  age.secrets = lib.mkIf config.dotfiles.backup.enable {
    backup-smb.file = ../../secrets/backup/jacurutu-smb.age;
    backup-restic.file = ../../secrets/backup/jacurutu-restic.age;
  };
  dotfiles.backup = {
    enable = true;
    nas = {
      address = fleet.devices.dar-es-balat.tailscaleIp;
      share = "backup-jacurutu";
      credentialsFile = config.age.secrets.backup-smb.path;
    };
    passwordFile = config.age.secrets.backup-restic.path;
    inhibitsSleep = true;
    statusPush.host = "sietch";
    jobs.files.paths = [
      "/vault/notes/coppermind"
      "/vault/userdata/media"
    ];
  };

  home-manager.users.kabilan = {
    home.packages = [ pkgs.spindle ];

    dotfiles.services = {
      mise-update.enable = true;
      update-app-pins.enable = true;
      codex-desktop.enable = true;
      dictator = {
        enable = true;
        activeProvider = "siren";
      };
      grok-bot.enable = true;
      mic-volume-enforce.enable = true;
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

    dotfiles.wallpaper.lockscreen = "$HOME/dotfiles/wallpapers/shoggoth-math-woodblock.png";
  };
}
