# Nightly Restic backup of Executor v2 to tleilax's own share on the NAS, over
# the tailnet (docs/backups.md). PGlite has no live backup, so Executor stops
# for the snapshot and starts again afterwards, and a new Executor image waits
# for a snapshot before it starts. A restore is useless without
# EXECUTOR_ENCRYPTION_KEY from secrets/executor/tleilax-v2-keys.env.age.
# Atlas is stateless; nothing else here holds data.
{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  fleet = import ../../lib/fleet.nix;
  executor = config.virtualisation.oci-containers.containers.executor-v2;
  dataDir = "/var/lib/executor-v2";

  resticEnv = {
    RESTIC_REPOSITORY = config.dotfiles.backup.repository;
    RESTIC_PASSWORD_FILE = config.dotfiles.backup.passwordFile;
    RESTIC_CACHE_DIR = "/var/cache/restic-backups-executor";
  };

  gate = pkgs.writeShellApplication {
    name = "backup-gate-executor";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.restic
      config.systemd.package
    ];
    runtimeEnv = resticEnv // {
      GATE_REPOSITORY_READY = config.dotfiles.backup.repositoryReady;
      GATE_DATA_DIR = dataDir;
    };
    text = builtins.readFile ./backup-gate.sh;
  };

  restoreCheck = pkgs.writeShellApplication {
    name = "backup-restore-check-executor";
    runtimeInputs = [
      config.virtualisation.podman.package
      pkgs.coreutils
      pkgs.findutils
      pkgs.git
      pkgs.gnugrep
      pkgs.restic
    ];
    runtimeEnv = resticEnv // {
      CHECK_REPOSITORY_READY = config.dotfiles.backup.repositoryReady;
      CHECK_TAG = "executor";
      CHECK_IMAGE = executor.image;
      CHECK_OWNER = executor.user;
      CHECK_DATA_DIR = dataDir;
      CHECK_ENV_FILE = pkgs.writeText "executor-v2-restore-check.env" (
        lib.concatLines (lib.mapAttrsToList (name: value: "${name}=${value}") executor.environment)
      );
      CHECK_KEYS_FILE = config.age.secrets.executor-v2-keys.path;
    };
    text = builtins.readFile ./backup-restore-check.sh;
  };
in
{
  imports = [ ../../modules/nixos/backup ];

  # Placeholders until Tony fills them on jacurutu (docs/backups.md); the
  # jobs refuse to run while the Restic password is the placeholder.
  age.secrets = {
    backup-smb.file = ../../secrets/backup/tleilax-smb.age;
    backup-restic.file = ../../secrets/backup/tleilax-restic.age;
  };

  dotfiles.backup = {
    enable = true;
    # Over the tailnet: tleilax's egress filter (network.nix) blocks the LAN.
    nas = {
      address = fleet.devices.dar-es-balat.tailscaleIp;
      share = "backup-tleilax";
      credentialsFile = config.age.secrets.backup-smb.path;
    };
    passwordFile = config.age.secrets.backup-restic.path;
    # 02:00 EST, 03:00 EDT.
    timer = {
      OnCalendar = "*-*-* 07:00:00 UTC";
      RandomizedDelaySec = "30m";
      Persistent = "true";
    };
    # Its own Hark credential and project; tleilax sends its status nowhere,
    # so it checks its own staleness.
    alert = {
      project = "Fleet";
      credentialFile = lib.mkIf (
        config.dotfiles.alerts.webhookFile != null
      ) config.age.secrets.hark-alerts.path;
    };
    staleness.ownJobs = true;
    jobs.executor = {
      paths = [ dataDir ];
      stopUnits = [ "podman-executor-v2.service" ];
    };
  };

  # The gate runs after the old container has stopped, and a failed condition
  # skips the start without failing the unit, so Restart= doesn't loop on it.
  systemd.services.podman-executor-v2.serviceConfig.ExecCondition = utils.escapeSystemdExecArgs [
    (lib.getExe gate)
    executor.image
  ];

  # These alert after their retries.
  dotfiles.alerts.exclude = [
    "restic-backups-executor.service"
    "restic-backups-check.service"
  ];

  environment.systemPackages = [ restoreCheck ];
}
