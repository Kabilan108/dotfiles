# TEMPORARY. Delete this module and its two imports in flake.nix once the
# kernel these hosts boot includes torvalds/linux 48691075b0ad.
#
# lib/assoc_array.c can chain a shortcut onto a shortcut. The keyring
# syscalls (add_key, keyctl, request_key) reach that bug and a local
# unprivileged process can turn it into root. Public PoC:
# https://github.com/Rat5ak/ASSOC_ARRAY_SHORTCUT-CHAIN-EoP
# No CVE yet. The fix is not in any released stable kernel or in this
# flake's nixpkgs. Every host here boots an affected kernel.
#
# Scope is the processes that run untrusted or agent code. kabilan's
# session is not filtered: GNOME keyring, gpg, ssh-agent and
# systemd-homed use the kernel keyring. jacurutu has no agent account
# and no agent runner unit, so this module is not imported there.
#
# A denied call returns EPERM. The process stays up.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  deniedSyscalls = [
    "add_key"
    "keyctl"
    "request_key"
  ];
  # Leading "~" is systemd's denylist form. mkAfter keeps an existing
  # allow list (atlas's @system-service) in front of these entries.
  keyringSyscallDeny = {
    SystemCallFilter = lib.mkAfter (map (name: "~${name}") deniedSyscalls);
    SystemCallErrorNumber = "EPERM";
  };

  filterHasDeny =
    filter: lib.isList filter && lib.all (name: lib.elem "~${name}" filter) deniedSyscalls;

  # crun calls keyctl to create a session keyring before exec, unless
  # containers.conf says keyring=false (podman then passes --no-new-keyring).
  # The systemd filter covers the container, so that setup call has to be
  # skipped or podman refuses to start.
  executorKeyringOff = pkgs.writeText "executor-v2-keyring-off.conf" ''
    [containers]
    keyring = false
  '';

  # dockerd's compiled profile is default_linux.go; default.json is the
  # same list. Both omit the keyring syscalls and use EPERM (errno 1).
  # Docker applies that profile inside the container. A SystemCallFilter
  # on docker-executor.service would only cover the docker CLI, which is
  # not the process that runs the workload.
  dockerKeyringStillDenied = pkgs.runCommand "docker-keyring-syscalls-denied" { } ''
    src=${pkgs.docker.moby-src}
    json="$src/vendor/github.com/moby/profiles/seccomp/default.json"
    gofile="$src/vendor/github.com/moby/profiles/seccomp/default_linux.go"
    if [[ ! -f "$json" || ! -f "$gofile" ]]; then
      echo "dockerd seccomp profile moved; update modules/nixos/keyring-lpe-mitigation.nix" >&2
      exit 1
    fi
    ${lib.getExe pkgs.jq} -e --argjson names ${lib.escapeShellArg (builtins.toJSON deniedSyscalls)} '
      .defaultAction == "SCMP_ACT_ERRNO" and .defaultErrnoRet == 1
      and ([.syscalls[].names[]] | all(. as $n | $names | index($n) | not))
    ' "$json" >/dev/null
    if grep -E -q '"add_key"|"keyctl"|"request_key"' "$gofile"; then
      echo "dockerd default seccomp now mentions a keyring syscall; deny it on the executor container explicitly" >&2
      exit 1
    fi
    touch "$out"
  '';

  hostName = config.networking.hostName;
in
{
  config = lib.mkMerge [
    (lib.mkIf (hostName == "tleilax") {
      systemd.services.atlas.serviceConfig = keyringSyscallDeny;
      systemd.services.podman-executor-v2 = {
        environment.CONTAINERS_CONF_OVERRIDE = "${executorKeyringOff}";
        serviceConfig = keyringSyscallDeny;
      };

      assertions = [
        {
          assertion = filterHasDeny config.systemd.services.atlas.serviceConfig.SystemCallFilter;
          message = "Temporary keyring mitigation: atlas.service lost the add_key/keyctl/request_key deny.";
        }
        {
          assertion =
            config.virtualisation.oci-containers.backend == "podman"
            && config.virtualisation.oci-containers.containers.executor-v2.privileged == false
            && filterHasDeny config.systemd.services.podman-executor-v2.serviceConfig.SystemCallFilter
            &&
              config.systemd.services.podman-executor-v2.environment.CONTAINERS_CONF_OVERRIDE
              == "${executorKeyringOff}";
          message = "Temporary keyring mitigation: podman-executor-v2 must stay unprivileged, deny the keyring syscalls, and skip crun's session keyring.";
        }
      ];
    })

    (lib.mkIf (hostName == "sietch") {
      # t3-code.service is the T3 agent server. Its children (agent
      # processes it spawns) inherit the filter. Interactive shells,
      # SSH sessions and the 'agents' tmux session do not.
      home-manager.users.kabilan.systemd.user.services.t3-code.Service =
        lib.mkIf config.home-manager.users.kabilan.dotfiles.services.t3-code.enable keyringSyscallDeny;

      # executor's workload is the container, not the docker CLI. Docker's
      # default seccomp profile already returns EPERM for these three
      # syscalls. The check below fails the system build if that stops.
      system.extraDependencies = [ dockerKeyringStillDenied ];

      assertions = [
        {
          assertion =
            config.home-manager.users.kabilan.dotfiles.services.t3-code.enable
            -> filterHasDeny config.home-manager.users.kabilan.systemd.user.services.t3-code.Service.SystemCallFilter;
          message = "Temporary keyring mitigation: t3-code.service lost the add_key/keyctl/request_key deny.";
        }
        {
          assertion =
            let
              executor = config.virtualisation.oci-containers.containers.executor;
              opts = lib.concatStringsSep " " executor.extraOptions;
            in
            config.virtualisation.oci-containers.backend == "docker"
            && executor.privileged == false
            && !lib.hasInfix "seccomp=unconfined" opts
            && !lib.hasInfix "seccomp:unconfined" opts;
          message = "Temporary keyring mitigation: the executor container must keep Docker's default seccomp profile (unprivileged, no seccomp=unconfined).";
        }
      ];
    })
  ];
}
