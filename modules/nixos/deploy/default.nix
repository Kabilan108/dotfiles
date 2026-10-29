# YubiKey-signed deploys; lib/fleet.nix `deploy` says which host plays which
# part. Every host gets deploy-tag, which bin/rebuild uses. The controller gets
# `deploy`. Receivers build signed tags through deploy-receiver.service.
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
      pkgs.git
      config.system.build.nixos-rebuild
    ];
    runtimeEnv = {
      DEPLOY_HOST = thisHost;
      DEPLOY_REPO_URL = deploy.repo;
      DEPLOY_BRANCH = deploy.branch;
      DEPLOY_STATE_DIR = stateDir;
    };
    text = builtins.readFile ./receiver.sh;
  };

  trigger = pkgs.writeShellApplication {
    name = "deploy-trigger";
    runtimeInputs = [
      pkgs.coreutils
      config.systemd.package
    ];
    runtimeEnv = {
      DEPLOY_HOST = thisHost;
      DEPLOY_STATE_FILE = "${stateDir}/deployed";
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
        HOME = "/root";
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
    };
  };

  # The fleet user may start the receiver, and nothing more: not stop or
  # restart it, and not pass it anything.
  security.polkit = lib.mkIf isReceiver {
    enable = true;
    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "deploy-receiver.service" &&
            action.lookup("verb") == "start" &&
            subject.user == "${fleet.hosts.${thisHost}.user}") {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
