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

  stateDir = "/var/lib/backup";
  mountPoint = "${stateDir}/nas";
  stagingDir = "/var/lib/backup-staging";
  statusDir = "/var/lib/backup-status";
  retryDir = "/run/backup-retry";
  hostKey = "/etc/ssh/ssh_host_ed25519_key";
  receivedDir = "${config.users.users.kabilan.home}/.local/state/backup-status";
  credentialAlerts = cfg.alert.credentialFile != null;
  staleMarks =
    if credentialAlerts then "/var/lib/backup-stale-check" else "${receivedDir}/.stale-alerted";

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
      stopUnits = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "podman-executor-v2.service" ];
        description = "Units stopped while the job takes its snapshot, for data that has no live backup. They start again when the job ends, whether or not the snapshot succeeded.";
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
      BACKUP_ALERT_CURL_CONFIG = lib.optionalString (!credentialAlerts) cfg.alert.curlConfig;
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
      BACKUP_HOST = thisHost;
      BACKUP_STATUS_DIR = statusDir;
      BACKUP_RECEIVED_DIR = receivedDir;
      BACKUP_STALE_MARKS = staleMarks;
      BACKUP_STALE_HOSTS = lib.concatStringsSep " " cfg.statusReceive;
      BACKUP_STALE_OWN_JOBS = lib.optionalString cfg.staleness.ownJobs (
        lib.concatStringsSep " " (lib.attrNames cfg.jobs)
      );
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

  guard = ''
    if [ "$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg cfg.passwordFile})" = ${cfg.placeholder} ]; then
      echo "backup: the Restic password is still the placeholder" >&2
      exit 1
    fi
  '';

  mountUnit = utils.escapeSystemdPath mountPoint;
  mountReset = lib.optionalString (cfg.nas != null) ''
    ${config.systemd.package}/bin/systemctl reset-failed ${mountUnit}.mount ${mountUnit}.automount || true
    ${config.systemd.package}/bin/systemctl start ${mountUnit}.automount || true
  '';

  repositoryCheck = mountReset + ''
    if [ ! -e ${lib.escapeShellArg cfg.repository}/config ]; then
      echo "backup: repository ${cfg.repository} is not reachable" >&2
      exit 1
    fi
  '';

  repositoryReady = pkgs.writeShellScript "backup-repository-ready" (guard + repositoryCheck);

  retryCommand = name: "${lib.getExe retry} ${name}";

  systemctl = "${config.systemd.package}/bin/systemctl";

  resticJob = name: job: {
    inherit (cfg) passwordFile repository inhibitsSleep;
    initialize = false;
    progressFps = 1.0 / 60;
    paths = job.paths ++ lib.optional (job.sqlite != { }) "${stagingDir}/${name}";
    inherit (job) exclude;
    extraBackupArgs = [
      "--retry-lock 1h"
      "--tag ${name}"
    ];
    timerConfig = cfg.timer;
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
      ${lib.optionalString (
        job.stopUnits != [ ]
      ) "${systemctl} stop ${lib.escapeShellArgs job.stopUnits}"}
    '';
    backupCleanupCommand = ''
      ${lib.optionalString (job.stopUnits != [ ]) ''
        ${systemctl} start ${lib.escapeShellArgs job.stopUnits} || echo "backup: starting the stopped units failed" >&2
      ''}
      ${lib.optionalString (job.sqlite != { }) "rm -rf -- ${stagingDir}/${name}"}
      ${lib.getExe status} ${name} || echo "backup: recording the status failed" >&2
      ${retryCommand name}
    '';
  };

  alertServiceConfig =
    if credentialAlerts then
      {
        DynamicUser = true;
        LoadCredential = "webhook:${cfg.alert.credentialFile}";
      }
    else
      { User = cfg.alert.user; };
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
        OnCalendar = "*-*-* 09:00:00 UTC";
        RandomizedDelaySec = "30m";
        Persistent = "true";
      };
    };

    inhibitsSleep = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    repositoryReady = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = repositoryReady;
      description = "Command that resets the NAS mount and fails fast when the repository can't be reached or the password is the placeholder.";
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
          OnCalendar = "*-*-08 08:00:00 UTC";
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
      credentialFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Root-only curl config (`url = "..."`) of the Hark webhook. When set,
          alerts and the staleness check run as a dynamic user that gets the
          file as a systemd credential, instead of as `user` with `curlConfig`.
        '';
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
        description = "Alert once when a checked job hasn't succeeded for this long, or a received host has sent no status.";
      };
      ownJobs = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Also check this host's own jobs, for a host that sends its status nowhere.";
      };
      timer = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          OnCalendar = "*-*-* 17:00:00 UTC";
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

    (lib.mkIf (cfg.nas != null) (
      lib.optionalAttrs (options ? age) { age.identityPaths = lib.mkAfter [ hostKey ]; }
      // {
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
        {
          assertion = !(credentialAlerts && cfg.statusReceive != [ ]);
          message = "dotfiles.backup: alert.credentialFile runs the staleness check as a dynamic user, which can't read the statuses received in kabilan's home";
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
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${lib.getExe alert} %i";
          }
          // alertServiceConfig;
        };
      }
      // lib.optionalAttrs (cfg.statusReceive != [ ] || cfg.staleness.ownJobs) {
        backup-stale-check = {
          description = "Alert when a host's backup status goes stale";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe staleCheck;
          }
          // alertServiceConfig
          // lib.optionalAttrs credentialAlerts { StateDirectory = "backup-stale-check"; };
        };
      };

      systemd.timers = lib.mkIf (cfg.statusReceive != [ ] || cfg.staleness.ownJobs) {
        backup-stale-check = {
          wantedBy = [ "timers.target" ];
          timerConfig = cfg.staleness.timer;
        };
      };

      environment.systemPackages = [ pkgs.restic ];
    })
  ];
}
