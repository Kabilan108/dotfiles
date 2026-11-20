{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  fleet = import ../../lib/fleet.nix;
  homeDir = config.users.users.kabilan.home;
  projectBackupRoots = [
    "/vault/work"
    "/vault/repos"
    "/vault/experiments"
  ];
  browserBackupRoots = [
    "${homeDir}/.config/net.imput.helium"
    "${homeDir}/.config/zen"
  ];
  projectBackupExcludes = [
    "node_modules"
    ".venv"
    "venv"
    ".direnv"
    ".uv-cache"
    ".uv_cache"
    "uv-cache"
    "uv-python"
    ".pnpm-store"
    ".npm"
    ".yarn/cache"
    ".yarn/unplugged"
    ".cargo/registry"
    ".cargo/git"
    ".gradle"
    "__pycache__"
    ".pytest_cache"
    ".mypy_cache"
    ".ruff_cache"
    ".next"
    ".nuxt"
    ".turbo"
  ];
  browserBackupExcludes = [
    "Cache"
    "Code Cache"
    "GPUCache"
    "ShaderCache"
    "GrShaderCache"
    "DawnCache"
    "DawnGraphiteCache"
    "DawnWebGPUCache"
    "cache2"
    "startupCache"
    "shader-cache"
  ];
in
{
  imports = [
    ./framework.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "jacurutu";
  dotfiles.mobergTailscale.enable = true;

  services.teamviewer.enable = true;

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "kabilan" ];
  };
  environment.etc."1password/custom_allowed_browsers" = {
    text = ''
      helium
      zen
      zen-beta
      .zen-beta-wrapped
    '';
    mode = "0755";
  };

  services.udev.extraHwdb = ''
    evdev:input:b0018v32ACp0006*
     KEYBOARD_KEY_100c6=reserved
  '';

  nixpkgs.overlays = [ inputs.baliset.overlays.default ];

  services.pipewire.wireplumber.extraConfig."50-mic-volume" = {
    "wireplumber.settings" = {
      "device.routes.default-source-volume" = 0.30;
    };
  };

  services.pcscd.enable = true;

  environment = {
    systemPackages = with pkgs; [
      age-plugin-yubikey
      fprintd
    ];
  };

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
    timer = {
      OnCalendar = "*-*-* 10:00:00 UTC";
      RandomizedDelaySec = "30m";
      Persistent = "true";
    };
    inhibitsSleep = true;
    statusPush.host = "sietch";
    jobs.files = {
      paths = [
        "/vault/notes/coppermind"
        "/vault/userdata/media"
        "/vault/moberg-data/backups"
        "/vault/moberg-data/projects"
      ]
      ++ projectBackupRoots
      ++ browserBackupRoots;
      exclude =
        lib.concatMap (
          root: map (subpath: "${root}/**/${subpath}") projectBackupExcludes ++ [ "!${root}/**/.git/**" ]
        ) projectBackupRoots
        ++ [
          "/vault/repos/zeta.nvim/vendor/zed"
          "/vault/work/moberg/maestro/vendor/t3code"
          "/vault/work/moberg/maestro/vendor/terragon-oss"
          "/vault/work/moberg/dev-server/vendor/jupyter-ai-persona-manager"
          "/vault/work/moberg/dev-server/vendor/jupyter-ai-jupyternaut"
          "/vault/work/moberg/dev-server/vendor/jupyter-ai-claude-code"
        ]
        ++ lib.concatMap (
          root: map (subpath: "${root}/**/${subpath}") browserBackupExcludes
        ) browserBackupRoots;
    };
  };

  home-manager.users.kabilan = {
    home.packages = [ pkgs.baliset ];

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

    programs.appimages.apps.t3code = {
      repo = "pingdotgg/t3code";
      pattern = "T3-Code-*.AppImage";
      downloadPattern = "*x86_64.AppImage";
      desktopName = "T3 Code";
      comment = "T3 Code Editor";
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
