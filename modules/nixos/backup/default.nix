# Restic backups to the NAS; runbook in docs/backups.md. Each host writes to
# its own SMB share. The NAS's immutable snapshots of that share protect older
# restore points from a compromised host, so no job here ever prunes.
{
  config,
  lib,
  options,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.dotfiles.backup;
  fleet = import ../../../lib/fleet.nix;
  thisHost = config.networking.hostName;

  # Root-only, so ordinary users can't trigger or browse the automount.
  stateDir = "/var/lib/backup";
  mountPoint = "${stateDir}/nas";
  stagingDir = "/var/lib/backup-staging";
  statusDir = "/var/lib/backup-status";
  retryDir = "/run/backup-retry";
  hostKey = "/etc/ssh/ssh_host_ed25519_key";
  # Where backup-status-receive stores other hosts' status files.
  receivedDir = "${config.users.users.kabilan.home}/.local/state/backup-status";

  sqliteType = lib.types.submodule {
    options = {
      database = lib.mkOption {
        type = lib.types.str;
        description = "Live SQLite database, copied with `.backup` instead of read directly.";
      };
      user = lib.mkOption {
        type = lib.types.str;
        description = "User (name or numeric UID) that owns the database and runs the copy.";
      };
    };
  };

  jobType = lib.types.submodule {
    options = {
      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      sqlite = lib.mkOption {
        type = lib.types.attrsOf sqliteType;
        default = { };
        description = "Databases copied into this job's staging directory before each run. Exclude the live files from `paths`.";
      };
    };
  };

  capture = pkgs.writeShellApplication {
    name = "backup-capture";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.sqlite
      pkgs.util-linux
    ];
    text = builtins.readFile ./capture.sh;
  };

  alert = pkgs.writeShellApplication {
    name = "backup-alert";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    runtimeEnv = {
      BACKUP_HOST = thisHost;
      BACKUP_STATUS_DIR = statusDir;
      BACKUP_ALERT_CURL_CONFIG = cfg.alert.curlConfig;
      BACKUP_ALERT_PROJECT = cfg.alert.project;
      BACKUP_ALERT_OUTPUT = lib.optionalString (cfg.alert.outputFile != null) cfg.alert.outputFile;
      BACKUP_RECEIVED_DIR = receivedDir;
    };
    text = builtins.readFile ./alert.sh;
  };

  staleCheck = pkgs.writeShellApplication {
    name = "backup-stale-check";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    runtimeEnv = {
      BACKUP_RECEIVED_DIR = receivedDir;
      BACKUP_STALE_HOSTS = lib.concatStringsSep " " cfg.statusReceive;
      BACKUP_STALE_AFTER_SEC = toString (cfg.staleness.afterHours * 3600);
      BACKUP_ALERT = lib.getExe alert;
    };
    text = builtins.readFile ./stale.sh;
  };

  status = pkgs.writeShellApplication {
    name = "backup-status";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.restic
      config.systemd.package
      config.programs.ssh.package
    ];
    runtimeEnv = {
      BACKUP_HOST = thisHost;
      BACKUP_STATUS_DIR = statusDir;
      BACKUP_REPOSITORY_DIR = cfg.repository;
      BACKUP_SIZE_ALERT_BYTES = toString (cfg.alert.repositorySizeGiB * 1024 * 1024 * 1024);
      BACKUP_FREE_ALERT_PERCENT = toString cfg.alert.nasFreePercent;
      BACKUP_PUSH_TARGET = lib.optionalString (
        cfg.statusPush != null
      ) "${cfg.statusPush.user}@${cfg.statusPush.host}";
      BACKUP_PUSH_KEY = hostKey;
    };
    text = builtins.readFile ./status.sh;
  };

  retry = pkgs.writeShellApplication {
    name = "backup-retry";
    runtimeInputs = [
      pkgs.coreutils
      config.systemd.package
    ];
    runtimeEnv = {
      BACKUP_RETRY_DIR = retryDir;
      BACKUP_RETRY_ATTEMPTS = toString cfg.retry.attempts;
      BACKUP_RETRY_DELAY_SEC = toString cfg.retry.delaySec;
    };
    text = builtins.readFile ./retry.sh;
  };

  statusReceive = pkgs.writeShellApplication {
    name = "backup-status-receive";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = builtins.readFile ./status-receive.sh;
  };

  # Refuses to run while either secret still holds the placeholder.
  guard = pkgs.writeShellScript "backup-guard" ''
    if [ "$(${pkgs.coreutils}/bin/cat "$RESTIC_PASSWORD_FILE")" = ${cfg.placeholder} ]; then
      echo "backup: the Restic password is still the placeholder" >&2
      exit 1
    fi
  '';

  # A burst of failed mounts during an outage trips the mount's start limit,
  # which leaves the automount failed and the share's path an empty local
  # directory until something resets it. Each run resets it first.
  mountUnit = utils.escapeSystemdPath mountPoint;
  mountReset = lib.optionalString (cfg.nas != null) ''
    ${config.systemd.package}/bin/systemctl reset-failed ${mountUnit}.mount ${mountUnit}.automount || true
    ${config.systemd.package}/bin/systemctl start ${mountUnit}.automount || true
  '';

  # Fails in seconds when the NAS is unreachable. Restic itself would keep
  # retrying the missing config with backoff for many minutes per attempt.
  repositoryCheck = mountReset + ''
    if [ ! -e ${lib.escapeShellArg cfg.repository}/config ]; then
      echo "backup: repository ${cfg.repository} is not reachable" >&2
      exit 1
    fi
  '';

  # Retries are counted by backup-retry, not systemd's Restart=: its start
  # limit is a time window, which slow attempts (a lock wait, a long upload)
  # outlast, so it would retry forever without alerting.
  retryCommand = name: "${lib.getExe retry} ${name}";

  resticJob = name: job: {
    inherit (cfg) passwordFile repository inhibitsSleep;
    initialize = false;
    # Without a terminal restic reports nothing until it ends; one line a
    # minute shows a long first run moving in the journal.
    progressFps = 1.0 / 60;
    paths = job.paths ++ lib.optional (job.sqlite != { }) "${stagingDir}/${name}";
    inherit (job) exclude;
    extraBackupArgs = [
      "--retry-lock 1h"
      "--tag ${name}"
    ];
    timerConfig = cfg.timer;
    # restic treats --files-from entries as patterns and silently skips one
    # that matches nothing, so a moved source would otherwise back up nothing.
    backupPrepareCommand = ''
      ${guard}
      ${repositoryCheck}
      for path in ${lib.escapeShellArgs job.paths}; do
        if [ ! -e "$path" ]; then
          echo "backup: source $path does not exist" >&2
          exit 1
        fi
      done
      ${lib.optionalString (job.sqlite != { }) ''
        ${lib.getExe capture} ${stagingDir}/${name} ${
          pkgs.writeText "backup-sqlite-${name}" (
            lib.concatStrings (
              lib.mapAttrsToList (dbName: db: "${dbName}\t${db.user}\t${db.database}\n") job.sqlite
            )
          )
        }
      ''}
    '';
    backupCleanupCommand = ''
      ${lib.optionalString (job.sqlite != { }) "rm -rf -- ${stagingDir}/${name}"}
      ${lib.getExe status} ${name} || echo "backup: recording the status failed" >&2
      ${retryCommand name}
    '';
  };
in
{
  options.dotfiles.backup = {
    enable = lib.mkEnableOption "Restic backups to the NAS";

    nas = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            address = lib.mkOption { type = lib.types.str; };
            share = lib.mkOption { type = lib.types.str; };
            credentialsFile = lib.mkOption {
              type = lib.types.str;
              description = "Root-only cifs credentials file (`username=` and `password=` lines).";
            };
          };
        }
      );
      default = null;
      description = "SMB share holding the repository. Null keeps the repository on a local path (tests).";
    };

    repository = lib.mkOption {
      type = lib.types.str;
      default = "${mountPoint}/restic";
    };

    passwordFile = lib.mkOption { type = lib.types.str; };

    placeholder = lib.mkOption {
      type = lib.types.str;
      default = "REPLACE_ME";
      description = "Value the encrypted placeholder secrets hold until Tony fills them in.";
    };

    jobs = lib.mkOption {
      type = lib.types.attrsOf jobType;
      default = { };
    };

    timer = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        OnCalendar = "00:00";
        RandomizedDelaySec = "30m";
        Persistent = "true";
      };
    };

    inhibitsSleep = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    retry = {
      attempts = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3;
      };
      delaySec = lib.mkOption {
        type = lib.types.ints.positive;
        default = 900;
      };
    };

    check = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      readDataSubset = lib.mkOption {
        type = lib.types.str;
        default = "5%";
      };
      timer = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          OnCalendar = "*-*-08 03:00";
          RandomizedDelaySec = "1h";
          Persistent = "true";
        };
      };
    };

    alert = {
      user = lib.mkOption {
        type = lib.types.str;
        default = "kabilan";
        description = "Alerts run as this user, so root never reads a user-writable curl config.";
      };
      curlConfig = lib.mkOption {
        type = lib.types.str;
        default = "/home/kabilan/.config/hark/integrations/fleet-maintenance.curl";
      };
      project = lib.mkOption {
        type = lib.types.str;
        default = "Dotfiles";
      };
      outputFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Write alert payloads here instead of sending them (tests).";
      };
      repositorySizeGiB = lib.mkOption {
        type = lib.types.ints.positive;
        default = 100;
      };
      nasFreePercent = lib.mkOption {
        type = lib.types.ints.between 0 100;
        default = 15;
      };
    };

    statusPush = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            host = lib.mkOption { type = lib.types.str; };
            user = lib.mkOption {
              type = lib.types.str;
              default = "kabilan";
            };
          };
        }
      );
      default = null;
      description = "Send each run's status to this host with the root-only host key.";
    };

    statusReceive = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Fleet hosts whose host key may write their status file here, as kabilan.";
    };

    staleness = {
      afterHours = lib.mkOption {
        type = lib.types.ints.positive;
        default = 72;
        description = "Alert once when a received host's job hasn't succeeded for this long, or the host has sent no status.";
      };
      timer = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          OnCalendar = "12:00";
          RandomizedDelaySec = "1h";
          Persistent = "true";
        };
      };
    };
  };

  config = lib.mkMerge [
    {
      users.users.kabilan.openssh.authorizedKeys.keys = map (
        host:
        let
          entry = fleet.hosts.${host};
        in
        "command=\"${lib.getExe statusReceive} ${host}\",restrict,from=\"${entry.tailscaleIp}\" ${entry.hostPubkey}"
      ) (builtins.filter (host: fleet.hosts.${host}.hostPubkey != null) cfg.statusReceive);
    }

    # A host with a NAS configured gets its root-only host key before backups
    # are switched on, because its backup secrets are encrypted to that key.
    (lib.mkIf (cfg.nas != null) (
      # agenix skips identities it can't read, so this is harmless before the
      # key exists. (The VM test has no agenix.)
      lib.optionalAttrs (options ? age) { age.identityPaths = lib.mkAfter [ hostKey ]; }
      // {

        # jacurutu runs no sshd, so nothing else creates its host key.
        system.activationScripts.backupHostKey = ''
          if [ ! -e ${hostKey} ]; then
            mkdir -p /etc/ssh
            ${config.programs.ssh.package}/bin/ssh-keygen -q -t ed25519 -N "" -C root@${thisHost} -f ${hostKey}
          fi
        '';
      }
    ))

    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.jobs != { };
          message = "dotfiles.backup: enable needs at least one job";
        }
      ];

      systemd.tmpfiles.rules = [
        "d ${stateDir} 0700 root root -"
        "d ${stagingDir} 0711 root root -"
        "d ${statusDir} 0755 root root -"
        "d ${retryDir} 0700 root root -"
      ];

      fileSystems = lib.mkIf (cfg.nas != null) {
        ${mountPoint} = {
          device = "//${cfg.nas.address}/${cfg.nas.share}";
          fsType = "cifs";
          options = [
            "credentials=${cfg.nas.credentialsFile}"
            "vers=3.1.1"
            "seal"
            "uid=0"
            "gid=0"
            "file_mode=0600"
            "dir_mode=0700"
            "nodev"
            "nosuid"
            "noexec"
            # Mounted on first use, so a laptop away from the NAS fails the run
            # instead of writing into an empty local directory.
            "x-systemd.automount"
            "x-systemd.idle-timeout=600"
            "x-systemd.mount-timeout=30s"
            "nofail"
            "_netdev"
          ];
        };
      };

      services.restic.backups =
        lib.mapAttrs resticJob cfg.jobs
        // lib.optionalAttrs cfg.check.enable {
          check = {
            inherit (cfg) passwordFile repository;
            initialize = false;
            paths = [ ];
            runCheck = true;
            checkOpts = [
              "--retry-lock 1h"
              "--read-data-subset=${cfg.check.readDataSubset}"
            ];
            timerConfig = cfg.check.timer;
            backupPrepareCommand = ''
              ${guard}
              ${repositoryCheck}
            '';
            backupCleanupCommand = retryCommand "check";
          };
        };

      systemd.services = {
        "backup-alert@" = {
          description = "Send a backup alert to Hark";
          serviceConfig = {
            Type = "oneshot";
            User = cfg.alert.user;
            ExecStart = "${lib.getExe alert} %i";
          };
        };
      }
      // lib.optionalAttrs (cfg.statusReceive != [ ]) {
        backup-stale-check = {
          description = "Alert when a host's received backup status goes stale";
          serviceConfig = {
            Type = "oneshot";
            User = cfg.alert.user;
            ExecStart = lib.getExe staleCheck;
          };
        };
      };

      systemd.timers = lib.mkIf (cfg.statusReceive != [ ]) {
        backup-stale-check = {
          wantedBy = [ "timers.target" ];
          timerConfig = cfg.staleness.timer;
        };
      };

      environment.systemPackages = [ pkgs.restic ];
    })
  ];
}
