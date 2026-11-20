rec {
  tailnet = "sole-pierce.ts.net";

  hosts = {
    jacurutu = {
      role = "control-plane";
      icon = "󰌢";
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
      hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMq054yvlbd3s0Zm6ElHrs7PfAVnWzP7Yboy6HzXu2t2";
      keys = {
        human = [
          "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIAU2WbCLrvbZce+BFRjxjqGfc2atw+UW1OzuUL0xoQP0AAAABHNzaDo= yk-nfc"
          "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIC2osOfuEavgTyeKIekDC3QRInB5F7+OwbNr8rI0gxeOAAAABHNzaDo= yk-nano"
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
        "moberg-status-jacurutu"
        "yk-nfc"
        "yk-nano"
        "yk-nfc-deploy"
        "yk-nano-deploy"
      ];
    };

    sietch = {
      role = "agent-worker";
      icon = "󰒋";
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
      canAccess = [ ];
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
        "moberg-bitbucket"
        "moberg-devserver3"
        "moberg-devserver4"
        "agent-sietch"
      ];
    };

    tleilax = {
      role = "credentials";
      icon = "󰐿";
      description = "Raspberry Pi 4 on Ethernet; locked-down box for credential services: Executor v2 and atlas. No coding agents run here. Only jacurutu reaches it; it accesses nothing.";
      tailscaleIp = "100.73.84.103";
      user = "kabilan";
      color = {
        name = "green";
        hex = "#a6e3a1";
        ansi = "1;32";
      };
      roots = [ ];
      canAccess = [ ];
      hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOKfdOeSaXW6GgykD4yw5OR9Vx4DgHOymTtWqLcHP27V";
      keys = {
        human = [ ];
        agent = [ ];
      };
      sshKeyFiles = [ ];
      initrdUnlock = {
        port = 2222;
        lanAddress = "10.0.0.67";
        hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIErYgLuP4LaU+jIb7dzXCsn55aqePJ1CBPHPgn61NQJS";
        jumpHost = "sietch";
      };
    };
  };

  ageRecipients = [
    "age1yubikey1qdk0g0dsffy22c3e239vwkymlncwh5jsktgmcm7pel3e852vwz2uk75d858"
    "age1yubikey1qgcaju2dyk8wjlpdweh2rqs9tx48x2rn9c6836kkhhg22ludqnxrcjqgglw"
  ];

  devices = {
    tko-pixel-9 = {
      role = "phone";
      model = "Pixel 9";
      os = "Android";
      tailscaleIp = "100.66.90.94";
      description = "Personal phone; Android app deployment over paired wireless ADB. Read the current connection port from Wireless debugging; pairing uses a separate temporary port.";
    };
    dar-es-balat = {
      role = "nas";
      model = "Synology DS225+";
      os = "Synology DSM";
      tailscaleIp = "100.70.188.62";
      description = "Synology NAS, tagged tag:nas. Agents work on it only interactively with Tony, through a browser. Network and access rules: ~/dotfiles/docs/nas-network-policy.md.";
    };
    tonys-ipad = {
      role = "tablet";
      model = "iPad (model not recorded; placeholder)";
      os = "iPadOS";
      tailscaleIp = "100.120.97.93";
      description = "Tony's iPad. Agents never connect to it.";
    };
  };

  extraAuthorizedKeys = {
    sietch = [
      "command=\"/etc/profiles/per-user/kabilan/bin/moberg-dev-checkouts\",restrict,from=\"100.64.0.0/10\" ${mobergStatusKey}"
    ];
  };

  mobergStatusKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINNgVKXKNqU9Mybb8UEVVa4jGvUYGhmaoGMvhwkJledu moberg-status@jacurutu";

  agentKeyRestrictions = "from=\"100.64.0.0/10\",no-agent-forwarding,no-X11-forwarding,no-port-forwarding";

  agentGateRestrictions = "command=\"/run/current-system/sw/bin/deploy-gate\",restrict,from=\"100.64.0.0/10\"";

  deploy = {
    repo = "https://github.com/Kabilan108/dotfiles.git";
    pushUrl = "git@github.com:Kabilan108/dotfiles.git";
    pushKnownHosts = "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl\n";
    branch = "nixos";
    controller = "jacurutu";
    receivers = [
      "sietch"
      "tleilax"
    ];
    gatedAgentLogins = [ "tleilax" ];
    signers = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINdYzCkPMjG7hmNBaBJnsvrlIae82j9oTFWAMqzLY1IjAAAABHNzaDo= yk-nfc-deploy"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDJI4FILtC/aP8+XHS/nviSP9oI/S9Nj8iGq/khkaLLmAAAABHNzaDo= yk-nano-deploy"
    ];
    signerYubiKeys = {
      yk-nfc-deploy = 37505721;
      yk-nano-deploy = 37605527;
    };
    defaultSigner = "yk-nfc-deploy";
    requirePin = true;
  };

  accessorsOf =
    target:
    builtins.filter (name: builtins.elem target hosts.${name}.canAccess) (builtins.attrNames hosts);

  authorizedKeysFor =
    target:
    let
      accessors = accessorsOf target;
      humanKeys = builtins.concatMap (name: hosts.${name}.keys.human) accessors;
      agentRestrictions =
        if builtins.elem target deploy.gatedAgentLogins then
          agentGateRestrictions
        else
          agentKeyRestrictions;
      agentKeys = builtins.concatMap (
        name: map (k: "${agentRestrictions} ${k}") hosts.${name}.keys.agent
      ) accessors;
    in
    humanKeys ++ agentKeys ++ (extraAuthorizedKeys.${target} or [ ]);
}
