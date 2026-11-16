# Executor v2 (beta), reachable as executor-v2.sole-pierce.ts.net. It starts
# empty; nothing migrates from v1 on sietch. Its session and encryption keys
# are generated into /var/lib/executor-v2 on first boot and never exist off
# this box, so back up the whole directory, keys included.
{ ... }:
let
  port = 8304;
in
{
  # Podman: no daemon to keep running on the Pi.
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  selfhost.tailnetServices.executor-v2.port = port;

  virtualisation.oci-containers.containers.executor-v2 = {
    # Bump by tag (each beta is a new tag), then re-pin the digest.
    image = "ghcr.io/usefulsoftwareco/executor-selfhost:2.0.0-beta.54@sha256:4a6cdf338ad62ec85a08986518f60cc9dc1d3f81a1468b1f7d7ecef6ca20d16b";
    volumes = [ "/var/lib/executor-v2:/app/data" ];
    environment = {
      # Host networking keeps the container under network.nix's egress filter
      # (a bridge would forward around it) and lets it reach atlas on
      # loopback. Everything else it runs listens on Unix sockets.
      HOST = "127.0.0.1";
      PORT = toString port;
      BETTER_AUTH_URL = "https://executor-v2.sole-pierce.ts.net";
      EXECUTOR_DISABLE_ANALYTICS = "1";
      # App code reaches public addresses only. Host-side MCP requests may
      # also reach the origins listed below.
      EXECUTOR_APPS_ALLOW_PRIVATE_FETCH = "false";
      EXECUTOR_URL_ALLOW_HTTP_ORIGINS = builtins.toJSON [ "http://127.0.0.1:8303" ];
      # Default 64 loaded app Workers is sized for a bigger box than a Pi 4.
      EXECUTOR_APP_WORKERS = "16";
    };
    extraOptions = [
      "--network=host"
      "--init"
    ];
  };

  # The entrypoint chowns the volume and drops to its own unprivileged user.
  systemd.tmpfiles.rules = [ "d /var/lib/executor-v2 0700 root root -" ];
}
