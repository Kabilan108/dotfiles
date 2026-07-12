rec {
  tailnet = "sole-pierce.ts.net";

  # Colors are catppuccin-mocha accents; ansi is the SGR code used in PS1.
  hosts = {
    jacurutu = {
      role = "control-plane";
      description = "Framework laptop; daily driver and orchestration brain. Nothing SSHes into it.";
      tailscaleIp = "100.108.28.4";
      user = "kabilan";
      color = {
        name = "blue";
        hex = "#89b4fa";
        ansi = "1;34";
      };
      roots = [
        "~/dotfiles"
        "~/repos"
      ];
      canAccess = [
        "sietch"
        "tleilax"
      ];
      hostPubkey = null;
      keys = {
        human = [
          "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIAU2WbCLrvbZce+BFRjxjqGfc2atw+UW1OzuUL0xoQP0AAAABHNzaDo= yk-nfc"
          "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIC2osOfuEavgTyeKIekDC3QRInB5F7+OwbNr8rI0gxeOAAAABHNzaDo= yk-nano"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPN/jpn1y7lmxhrBSmApiVvA+H2YN3AFkczBJbKIGVUe kabilan@jacurutu"
        ];
        agent = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDj7GbeFlXYTwXBodBwKtnYcj5Y55j9RNH7QUprk/Zfb agent@jacurutu"
        ];
      };
      sshKeyFiles = [
        "github"
        "moberg-bitbucket"
        "moberg-devserver3"
        "moberg-devserver4"
        "moberg-mobile-dev"
        "agent-jacurutu"
        "yk-nfc"
        "yk-nano"
      ];
    };

    sietch = {
      role = "agent-worker";
      description = "Server; runs day-job agent sessions (t3 serve + codex remote-control in the 'agents' tmux session, port 3773), selfhost services behind Tailscale Services, and the authoritative tracer archive.";
      tailscaleIp = "100.71.183.33";
      user = "kabilan";
      color = {
        name = "mauve";
        hex = "#cba6f7";
        ansi = "1;35";
      };
      roots = [
        "/vault/work/moberg"
        "~/dotfiles"
        "~/repos"
      ];
      canAccess = [ "tleilax" ];
      hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK4epXn3of3DRuL94bGopsFYecrci2nviKPJdibX3T0r";
      keys = {
        human = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDW1t7U7qDPNYEVWqnxivPK21jkOM5OFwQRmlrQh7XoE kabilan@sietch"
        ];
        agent = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEzgKJgqnWs1c8Psf5HrCJXTPJ2oHNpyMzjch6/6/HZS agent@sietch"
        ];
      };
      sshKeyFiles = [
        "github"
        "do-droplet"
        "gh-dotfiles-deploy"
        "moberg-bitbucket"
        "moberg-devserver3"
        "agent-sietch"
      ];
    };

    tleilax = {
      role = "appliance";
      description = "Raspberry Pi 4; airplay/jellyfin remote today, first dedicated agent box later. Accesses nothing.";
      tailscaleIp = "100.73.84.103";
      user = "kabilan";
      color = {
        name = "green";
        hex = "#a6e3a1";
        ansi = "1;32";
      };
      roots = [ "~/dotfiles" ];
      canAccess = [ ];
      hostPubkey = null;
      keys = {
        human = [ ];
        agent = [ ];
      };
      sshKeyFiles = [ ];
    };
  };

  # Extra authorized keys per host, outside the access matrix.
  extraAuthorizedKeys = { };

  agentKeyRestrictions = "from=\"100.64.0.0/10\",no-agent-forwarding,no-X11-forwarding,no-port-forwarding";

  accessorsOf =
    target:
    builtins.filter (name: builtins.elem target hosts.${name}.canAccess) (builtins.attrNames hosts);

  authorizedKeysFor =
    target:
    let
      accessors = accessorsOf target;
      humanKeys = builtins.concatMap (name: hosts.${name}.keys.human) accessors;
      agentKeys = builtins.concatMap (
        name: map (k: "${agentKeyRestrictions} ${k}") hosts.${name}.keys.agent
      ) accessors;
    in
    humanKeys ++ agentKeys ++ (extraAuthorizedKeys.${target} or [ ]);
}
