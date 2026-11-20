{
  config,
  lib,
  pkgs,
  ...
}:
let
  fleet = import ../../../lib/fleet.nix;
  inherit (fleet) deploy;
  thisHost = config.networking.hostName;
  isReceiver = builtins.elem thisHost deploy.receivers;
  isGated = builtins.elem thisHost deploy.gatedAgentLogins;
  deployHosts = [ deploy.controller ] ++ deploy.receivers;
  stateDir = "/var/lib/deploy-receiver";
  triggerSocket = "/run/deploy-trigger.sock";
  runningNixosVersion = "/run/current-system/sw/bin/nixos-version";
  switchLock = "/run/fleet-switch.lock";
  runsFile = "/run/deploy-receiver/runs";

  receiverNixConf = pkgs.runCommand "deploy-receiver-nix-conf" { } ''
    mkdir "$out"
    grep -Ev '^[[:space:]]*!?include[[:space:]]' ${
      config.environment.etc."nix/nix.conf".source
    } > "$out/nix.conf"
    if grep -q include "$out/nix.conf"; then
      echo "an include survived in the receiver's nix.conf" >&2
      exit 1
    fi
  '';

  allowedSigners = pkgs.writeText "deploy-signers" (
    lib.concatMapStrings (
      key: "${lib.last (lib.splitString " " key)} namespaces=\"git\" ${key}\n"
    ) deploy.signers
  );

  deployTag = pkgs.writeShellApplication {
    name = "deploy-tag";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.git
      pkgs.gnugrep
      pkgs.gnused
      config.programs.ssh.package
    ];
    runtimeEnv = {
      DEPLOY_SIGNERS = "${allowedSigners}";
      DEPLOY_PUSH_URL = deploy.pushUrl;
      DEPLOY_PUSH_KNOWN_HOSTS = "${pkgs.writeText "deploy-push-known-hosts" deploy.pushKnownHosts}";
      DEPLOY_REQUIRE_TOUCH = "1";
      DEPLOY_REQUIRE_PIN = if deploy.requirePin then "1" else "0";
      DEPLOY_CONTROLLER = deploy.controller;
      DEPLOY_RECEIVERS = lib.concatStringsSep " " deploy.receivers;
    };
    text = builtins.readFile ./deploy-tag.sh;
  };

  signerNames = map (key: lib.last (lib.splitString " " key)) deploy.signers;

  deployKey = pkgs.writeShellApplication {
    name = "deploy-key";
    runtimeInputs = [ pkgs.yubikey-manager ];
    runtimeEnv = {
      DEPLOY_KEY_SERIALS = lib.concatStringsSep " " (
        lib.mapAttrsToList (name: serial: "${toString serial}=${name}") deploy.signerYubiKeys
      );
      DEPLOY_DEFAULT_KEY = deploy.defaultSigner;
    };
    text = builtins.readFile ./deploy-key.sh;
  };

  deploySwitch = pkgs.writeShellApplication {
    name = "deploy-switch";
    runtimeInputs = [
      deployTag
      pkgs.coreutils
      pkgs.git
      pkgs.util-linux
      config.system.build.nixos-rebuild
    ];
    runtimeEnv = {
      DEPLOY_SWITCH_LOCK = switchLock;
      DEPLOY_NIXOS_VERSION = runningNixosVersion;
    };
    text = builtins.readFile ./deploy-switch.sh;
  };

  deployWait = pkgs.writeShellApplication {
    name = "deploy-wait";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gh
      pkgs.git
      pkgs.gnutar
      pkgs.jq
      pkgs.python3
      config.nix.package
    ];
    runtimeEnv = {
      DEPLOY_GITHUB_REPO = lib.removeSuffix ".git" (lib.removePrefix "https://github.com/" deploy.repo);
      DEPLOY_REPO_URL = deploy.repo;
    };
    text = builtins.readFile ./deploy-wait.sh;
  };

  deployCommand = pkgs.writeShellApplication {
    name = "deploy";
    runtimeInputs = [
      deployKey
      deploySwitch
      deployTag
      deployWait
      pkgs.coreutils
      pkgs.git
      pkgs.gnugrep
      pkgs.gnused
      config.programs.ssh.package
    ];
    runtimeEnv = {
      DEPLOY_CONTROLLER = deploy.controller;
      DEPLOY_RECEIVERS = lib.concatStringsSep " " deploy.receivers;
      DEPLOY_BRANCH = deploy.branch;
      DEPLOY_NIXOS_VERSION = runningNixosVersion;
    };
    text = builtins.readFile ./deploy.sh;
  };

  receiver = pkgs.writeShellApplication {
    name = "deploy-receiver";
    runtimeInputs = [
      deployTag
      pkgs.coreutils
      pkgs.gawk
      pkgs.git
      config.nix.package
      config.system.build.nixos-rebuild
      pkgs.util-linux
    ];
    runtimeEnv = {
      DEPLOY_HOST = thisHost;
      DEPLOY_REPO_URL = deploy.repo;
      DEPLOY_BRANCH = deploy.branch;
      DEPLOY_STATE_DIR = stateDir;
      DEPLOY_NIXOS_VERSION = runningNixosVersion;
      DEPLOY_SWITCH_LOCK = switchLock;
    };
    text = builtins.readFile ./receiver.sh;
  };

  runRecord = pkgs.writeShellApplication {
    name = "deploy-receiver-run";
    runtimeInputs = [
      pkgs.coreutils
      config.systemd.package
    ];
    runtimeEnv.DEPLOY_RUNS = runsFile;
    text = builtins.readFile ./run-record.sh;
  };

  broker = pkgs.writeShellApplication {
    name = "deploy-trigger-broker";
    runtimeInputs = [ config.systemd.package ];
    text = builtins.readFile ./broker.sh;
  };

  trigger = pkgs.writeShellApplication {
    name = "deploy-trigger";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.socat
      config.systemd.package
    ];
    runtimeEnv = {
      DEPLOY_HOST = thisHost;
      DEPLOY_STATE_FILE = "${stateDir}/deployed";
      DEPLOY_RUNS = runsFile;
      DEPLOY_NIXOS_VERSION = runningNixosVersion;
      DEPLOY_TRIGGER_SOCKET = triggerSocket;
    };
    text = builtins.readFile ./trigger.sh;
  };

  gate = pkgs.writeShellApplication {
    name = "deploy-gate";
    runtimeInputs = [ trigger ];
    inheritPath = false;
    runtimeEnv.DEPLOY_GATE_SESSIONIZER = "/run/current-system/sw/bin/sessionizer";
    text = builtins.readFile ./gate.sh;
  };
in
{
  options.dotfiles.deploy.receiverProgram = lib.mkOption {
    type = lib.types.str;
    default = lib.getExe receiver;
    internal = true;
    description = "Program deploy-receiver.service runs under deploy-receiver-run. Tests swap in a stand-in.";
  };

  config = {
    assertions = [
      {
        assertion = builtins.all (lib.hasPrefix "sk-") deploy.signers;
        message = "lib/fleet.nix deploy.signers must all be security keys (sk-...).";
      }
      {
        assertion =
          lib.all (name: builtins.elem name signerNames) (builtins.attrNames deploy.signerYubiKeys)
          && deploy.signerYubiKeys ? ${deploy.defaultSigner};
        message = "lib/fleet.nix deploy.signerYubiKeys must name only keys in deploy.signers, and include deploy.defaultSigner.";
      }
      {
        assertion =
          !(fleet.hosts ? fleet)
          && builtins.all (name: name != "fleet" && builtins.match "[a-z0-9-]+" name != null) deployHosts;
        message = "lib/fleet.nix: deploy host names must match [a-z0-9-]+, and none may be named fleet.";
      }
      {
        assertion = lib.hasInfix switchLock (builtins.readFile ../../../bin/rebuild);
        message = "bin/rebuild must switch under the same lock as the receiver (${switchLock}).";
      }
      {
        assertion =
          !isGated || builtins.any (pkg: lib.getName pkg == "sessionizer") config.environment.systemPackages;
        message = "${thisHost} is in lib/fleet.nix deploy.gatedAgentLogins, so it needs sessionizer in environment.systemPackages.";
      }
    ];

    systemd.tmpfiles.rules = [ "f ${switchLock} 0600 root root -" ];

    environment.systemPackages = [
      deploySwitch
      deployTag
    ]
    ++ lib.optionals (thisHost == deploy.controller) [
      deployCommand
      deployKey
      deployWait
    ]
    ++ lib.optional isReceiver trigger
    ++ lib.optional isGated gate;

    systemd.services.deploy-receiver = lib.mkIf isReceiver {
      description = "Build and switch to the newest signed deploy tag";
      restartIfChanged = false;
      unitConfig.X-StopOnRemoval = false;
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment =
        config.nix.envVars
        // {
          HOME = stateDir;
          XDG_CONFIG_HOME = "${stateDir}/config";
          XDG_DATA_HOME = "${stateDir}/data";
          XDG_STATE_HOME = "${stateDir}/state";
          XDG_CACHE_HOME = "/var/cache/deploy-receiver";
          NIX_CONF_DIR = "${receiverNixConf}";
          NIX_USER_CONF_FILES = "";
          NIX_CONFIG = "";
          NIX_REMOTE = "local";
          GIT_CONFIG_GLOBAL = "/dev/null";
          GIT_CONFIG_NOSYSTEM = "1";
        }
        // config.networking.proxy.envVars;
      path = [
        pkgs.gnutar
        pkgs.gzip
        pkgs.xz.bin
        config.nix.package.out
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe runRecord} ${config.dotfiles.deploy.receiverProgram}";
        StateDirectory = "deploy-receiver";
        CacheDirectory = "deploy-receiver";
        RuntimeDirectory = "deploy-receiver";
        RuntimeDirectoryPreserve = "yes";
      };
    };

    users.groups.deploy-trigger = lib.mkIf isReceiver {
      members = [ fleet.hosts.${thisHost}.user ];
    };

    systemd.sockets.deploy-trigger = lib.mkIf isReceiver {
      description = "Deploy trigger";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = triggerSocket;
        Accept = true;
        SocketUser = "root";
        SocketGroup = "deploy-trigger";
        SocketMode = "0660";
        MaxConnections = 4;
      };
    };

    systemd.services."deploy-trigger@" = lib.mkIf isReceiver {
      description = "Queue the deploy receiver for a deploy-trigger caller";
      serviceConfig = {
        ExecStart = lib.getExe broker;
        RuntimeMaxSec = 30;
        StandardInput = "socket";
        StandardOutput = "socket";
        StandardError = "socket";
      };
    };
  };
}
