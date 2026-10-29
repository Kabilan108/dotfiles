# YubiKey-signed deploys; lib/fleet.nix `deploy` says which host plays which
# part. Every host gets deploy-tag, which bin/rebuild uses. The controller gets
# `deploy`. Receivers build signed tags through deploy-receiver.service, which
# the deploy-trigger socket starts.
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
  stateDir = "/var/lib/deploy-receiver";
  triggerSocket = "/run/deploy-trigger.sock";
  runningNixosVersion = "/run/current-system/sw/bin/nixos-version";

  # The receiver's Nix reads only this file: the system nix.conf without its
  # include lines, so nothing outside the store (such as the access-token
  # include) reaches a root Nix process. Its directory has no registry,
  # machines or netrc file either.
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

  # The principal is the key's comment (yk-nfc, yk-nano).
  allowedSigners = pkgs.writeText "deploy-signers" (
    lib.concatMapStrings (
      key: "${lib.last (lib.splitString " " key)} namespaces=\"git\" ${key}\n"
    ) deploy.signers
  );

  deployTag = pkgs.writeShellApplication {
    name = "deploy-tag";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.gnugrep
      pkgs.gnused
      config.programs.ssh.package
    ];
    runtimeEnv = {
      DEPLOY_SIGNERS = "${allowedSigners}";
      DEPLOY_REQUIRE_TOUCH = "1";
      DEPLOY_REQUIRE_PIN = if deploy.requirePin then "1" else "0";
    };
    text = builtins.readFile ./deploy-tag.sh;
  };

  deployCommand = pkgs.writeShellApplication {
    name = "deploy";
    runtimeInputs = [
      deployTag
      pkgs.coreutils
      pkgs.git
      pkgs.gnugrep
      config.programs.ssh.package
    ];
    runtimeEnv = {
      DEPLOY_HOSTS = lib.concatStringsSep " " deploy.receivers;
      DEPLOY_BRANCH = deploy.branch;
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
    ];
    runtimeEnv = {
      DEPLOY_HOST = thisHost;
      DEPLOY_REPO_URL = deploy.repo;
      DEPLOY_BRANCH = deploy.branch;
      DEPLOY_STATE_DIR = stateDir;
      DEPLOY_NIXOS_VERSION = runningNixosVersion;
    };
    text = builtins.readFile ./receiver.sh;
  };

  broker = pkgs.writeShellApplication {
    name = "deploy-trigger-broker";
    runtimeInputs = [
      pkgs.coreutils
      config.systemd.package
    ];
    runtimeEnv = {
      DEPLOY_HOST = thisHost;
      DEPLOY_STATE_FILE = "${stateDir}/deployed";
      DEPLOY_NIXOS_VERSION = runningNixosVersion;
    };
    text = builtins.readFile ./broker.sh;
  };

  trigger = pkgs.writeShellApplication {
    name = "deploy-trigger";
    runtimeInputs = [ pkgs.socat ];
    runtimeEnv.DEPLOY_TRIGGER_SOCKET = triggerSocket;
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
  assertions = [
    {
      # deploy-tag reads touch and PIN from the signature, which only
      # security keys carry.
      assertion = builtins.all (lib.hasPrefix "sk-") deploy.signers;
      message = "lib/fleet.nix deploy.signers must all be security keys (sk-...).";
    }
  ];

  environment.systemPackages = [
    deployTag
  ]
  ++ lib.optional (thisHost == deploy.controller) deployCommand
  ++ lib.optional isReceiver trigger
  ++ lib.optional (builtins.elem thisHost deploy.gatedAgentLogins) gate;

  systemd.services.deploy-receiver = lib.mkIf isReceiver {
    description = "Build and switch to the newest signed deploy tag";
    # Like nixos-upgrade: the switch it runs must not stop or restart it.
    restartIfChanged = false;
    unitConfig.X-StopOnRemoval = false;
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment =
      config.nix.envVars
      // {
        # Root's Nix and git read only store files and root-owned paths.
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
      ExecStart = lib.getExe receiver;
      StateDirectory = "deploy-receiver";
      CacheDirectory = "deploy-receiver";
    };
  };

  # Members of deploy-trigger may connect to the socket. Each connection runs
  # the broker as root, which starts the receiver with a fixed job mode and
  # reads nothing from the caller. This is a socket rather than a polkit rule
  # because systemd doesn't pass the job mode to polkit: a rule allowing
  # "start" would also allow --job-mode=flush.
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
    description = "Start the deploy receiver for a deploy-trigger caller";
    # A switch must not cut off the caller's log stream.
    restartIfChanged = false;
    serviceConfig = {
      ExecStart = lib.getExe broker;
      StandardInput = "socket";
      StandardOutput = "socket";
      StandardError = "socket";
    };
  };
}
