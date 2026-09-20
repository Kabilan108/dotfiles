{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceName = "t3-v2-preview-1887";
  serviceUser = "t3-preview";
  openAIProxyUser = "t3-openai-proxy";
  claudeProxyUser = "t3-claude-proxy";
  t3Home = "/home/kabilan/.t3-v2-preview-1887";
  codexHome = "${t3Home}/codex";
  claudeHome = "${t3Home}/claude-home";
  piHome = "${t3Home}/pi";
  projectsDir = "${t3Home}/projects";
  openAIProxyPort = 8318;
  claudeProxyPort = 8319;
  t3Port = 3773;

  t3Preview = pkgs.callPackage ../packages/t3-preview.nix { };
  codexPreview = pkgs.callPackage ../packages/codex-preview.nix { };
  piCodingAgent = pkgs.callPackage ../packages/pi-coding-agent { };
  cliproxyapiRestricted = pkgs.callPackage ../packages/cliproxyapi-openai-only.nix { };

  openAIModels = [
    "gpt-5.5"
    "gpt-5.6-luna"
    "gpt-5.6-sol"
    "gpt-5.6-terra"
    "gpt-6-astra"
    "codex-auto-review"
  ];

  claudeModels = [
    "claude-3-5-haiku-20241022"
    "claude-3-7-sonnet-20250219"
    "claude-fable-5"
    "claude-fable-5-1"
    "claude-haiku-4-5-20251001"
    "claude-opus-4-1-20250805"
    "claude-opus-4-20250514"
    "claude-opus-4-5-20251101"
    "claude-opus-4-6"
    "claude-opus-4-7"
    "claude-opus-4-8"
    "claude-opus-5"
    "claude-sonnet-4-20250514"
    "claude-sonnet-4-5-20250929"
    "claude-sonnet-4-6"
    "claude-sonnet-5"
  ];

  mkProxyConfigBase =
    {
      name,
      proxyUser,
      port,
      localApiKey,
      models,
    }:
    (pkgs.formats.yaml { }).generate name {
      host = "127.0.0.1";
      inherit port;
      "auth-dir" = "/var/lib/${proxyUser}/auth";
      "api-keys" = [ localApiKey ];
      "remote-management" = {
        "allow-remote" = false;
        "disable-control-panel" = true;
      };
      "usage-statistics-enabled" = false;
      "logging-to-file" = false;
      routing = {
        strategy = "round-robin";
        "session-affinity" = true;
        "session-affinity-ttl" = "1h";
      };
      "openai-compatibility" = [
        {
          name = "central-${name}";
          "base-url" = "https://cliproxyapi.sole-pierce.ts.net/v1";
          "request-retry" = 0;
          "api-key-entries" = [ ];
          models = map (model: {
            name = model;
            alias = model;
            "display-name" = model;
            "input-modalities" = [
              "text"
              "image"
            ];
            "output-modalities" = [ "text" ];
          }) models;
        }
      ];
    };

  openAIProxyConfigBase = mkProxyConfigBase {
    name = "openai-only";
    proxyUser = openAIProxyUser;
    port = openAIProxyPort;
    localApiKey = "t3-openai-local";
    models = openAIModels;
  };

  claudeProxyConfigBase = mkProxyConfigBase {
    name = "claude-only";
    proxyUser = claudeProxyUser;
    port = claudeProxyPort;
    localApiKey = "t3-claude-local";
    models = claudeModels;
  };

  codexCatalogSource = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/openai/codex/rust-v0.155.1/codex-rs/models-manager/models.json";
    hash = "sha256-iXYU5ROlkbNi92w05LTTGvWAmitS+MCrV/KZDFv0qz0=";
  };
  codexModelCatalog =
    pkgs.runCommand "t3-preview-codex-models.json" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        jq --argjson allowed '${builtins.toJSON openAIModels}' \
          '{models: [.models[] | select(.slug as $slug | $allowed | index($slug))]}' \
          ${codexCatalogSource} > "$out"
      '';
  initialT3Settings = pkgs.writeText "t3-preview-initial-settings.json" (
    builtins.toJSON {
      providers = {
        codex.enabled = true;
        claudeAgent = {
          enabled = true;
          binaryPath = lib.getExe claudeCodeProxy;
          homePath = claudeHome;
          customModels = claudeModels;
        };
        pi.enabled = true;
      };
    }
  );

  claudeSettings = pkgs.writeText "t3-preview-claude-settings.json" (
    builtins.toJSON {
      cleanupPeriodDays = 99999999;
      env = {
        API_TIMEOUT_MS = "600000";
        BASH_DEFAULT_TIMEOUT_MS = "600000";
        BASH_MAX_TIMEOUT_MS = "600000";
        CLAUDE_API_TIMEOUT = "600000";
        CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = "1";
        DISABLE_TELEMETRY = "1";
      };
      model = "claude-fable-5-1";
      alwaysThinkingEnabled = true;
      effortLevel = "low";
    }
  );

  piOpenAIOnly = pkgs.writeShellApplication {
    name = "pi";
    text = ''
      export PI_CODING_AGENT_DIR=${lib.escapeShellArg piHome}
      export T3_OPENAI_GATEWAY_KEY=t3-openai-local
      unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN
      exec ${lib.getExe piCodingAgent} "$@"
    '';
  };

  claudeCodeProxy = pkgs.writeShellApplication {
    name = "claude";
    text = ''
      export ANTHROPIC_BASE_URL=http://127.0.0.1:${toString claudeProxyPort}
      export ANTHROPIC_AUTH_TOKEN=t3-claude-local
      export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
      unset ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN
      exec ${lib.getExe pkgs.claude-code} "$@"
    '';
  };

  mkRestrictedProxyService =
    {
      description,
      proxyUser,
      configBase,
      secretName,
    }:
    {
      inherit description;
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = proxyUser;
        Group = proxyUser;
        StateDirectory = proxyUser;
        StateDirectoryMode = "0700";
        EnvironmentFile = config.age.secrets.${secretName}.path;
        ExecStart = "${lib.getExe cliproxyapiRestricted} --config /var/lib/${proxyUser}/config.yaml";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
      path = [ pkgs.yq-go ];
      preStart = ''
        umask 077
        yq '
          ."openai-compatibility"[0]."api-key-entries" = [
            {"api-key": strenv(CLIPROXY_UPSTREAM_KEY)}
          ]
        ' ${configBase} > /var/lib/${proxyUser}/config.yaml
      '';
    };
in
{
  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "claude-code";

  age.secrets.t3-openai-proxy-env = {
    file = ../secrets/t3-openai-proxy-env.age;
    owner = openAIProxyUser;
    group = openAIProxyUser;
    mode = "0400";
  };

  age.secrets.t3-claude-proxy-env = {
    file = ../secrets/t3-openai-proxy-env.age;
    owner = claudeProxyUser;
    group = claudeProxyUser;
    mode = "0400";
  };

  users.groups.${serviceUser} = { };
  users.groups.${openAIProxyUser} = { };
  users.groups.${claudeProxyUser} = { };

  users.users.${serviceUser} = {
    isSystemUser = true;
    group = serviceUser;
    home = t3Home;
    shell = pkgs.bashInteractive;
  };

  users.users.${openAIProxyUser} = {
    isSystemUser = true;
    group = openAIProxyUser;
    home = "/var/lib/${openAIProxyUser}";
  };

  users.users.${claudeProxyUser} = {
    isSystemUser = true;
    group = claudeProxyUser;
    home = "/var/lib/${claudeProxyUser}";
  };

  environment.systemPackages = [
    claudeCodeProxy
    codexPreview
    piOpenAIOnly
  ];
  environment.variables.T3_OPENAI_GATEWAY_KEY = "t3-openai-local";

  environment.etc."t3-v2-preview-1887/codex-models.json".source = codexModelCatalog;

  system.activationScripts.t3V2PreviewUserFiles = {
    deps = [ "users" ];
    text = ''
      ${pkgs.coreutils}/bin/install -d -m 0700 -o ${serviceUser} -g ${serviceUser} \
        ${t3Home} ${codexHome} ${claudeHome} ${claudeHome}/.claude ${piHome} \
        ${projectsDir} ${t3Home}/userdata

      if [[ ! -e ${t3Home}/userdata/settings.json ]]; then
        ${pkgs.coreutils}/bin/install -m 0600 -o ${serviceUser} -g ${serviceUser} \
          ${initialT3Settings} ${t3Home}/userdata/settings.json
      fi

      settings_tmp="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.jq}/bin/jq \
        --arg binary ${lib.escapeShellArg (lib.getExe claudeCodeProxy)} \
        --arg home ${lib.escapeShellArg claudeHome} \
        --argjson models ${lib.escapeShellArg (builtins.toJSON claudeModels)} \
        '
          .providers = (.providers // {}) |
          .providers.codex = ((.providers.codex // {}) + {enabled: true}) |
          .providers.claudeAgent = ((.providers.claudeAgent // {}) + {
            enabled: true,
            binaryPath: $binary,
            homePath: $home,
            customModels: $models
          }) |
          .providers.pi = ((.providers.pi // {}) + {enabled: true})
        ' ${t3Home}/userdata/settings.json > "$settings_tmp"
      ${pkgs.coreutils}/bin/install -m 0600 -o ${serviceUser} -g ${serviceUser} \
        "$settings_tmp" ${t3Home}/userdata/settings.json
      ${pkgs.coreutils}/bin/rm -f "$settings_tmp"

      ${pkgs.coreutils}/bin/ln -sfnT ${../codex/config.toml} ${codexHome}/config.toml
      ${pkgs.coreutils}/bin/ln -sfnT ${../pi/models.json} ${piHome}/models.json
      ${pkgs.coreutils}/bin/ln -sfnT ${../pi/settings.json} ${piHome}/settings.json
      ${pkgs.coreutils}/bin/install -m 0600 -o ${serviceUser} -g ${serviceUser} \
        ${claudeSettings} ${claudeHome}/.claude/settings.json
    '';
  };

  systemd.services.${openAIProxyUser} = mkRestrictedProxyService {
    description = "OpenAI-only CLIProxyAPI gateway for the T3 v2 preview";
    proxyUser = openAIProxyUser;
    configBase = openAIProxyConfigBase;
    secretName = "t3-openai-proxy-env";
  };

  systemd.services.${claudeProxyUser} = mkRestrictedProxyService {
    description = "Claude-only CLIProxyAPI gateway for the T3 v2 preview";
    proxyUser = claudeProxyUser;
    configBase = claudeProxyConfigBase;
    secretName = "t3-claude-proxy-env";
  };

  systemd.services.${serviceName} = {
    description = "T3 Code Orchestrator v2 preview 1887";
    after = [
      "network-online.target"
      "${openAIProxyUser}.service"
      "${claudeProxyUser}.service"
    ];
    wants = [ "network-online.target" ];
    requires = [
      "${openAIProxyUser}.service"
      "${claudeProxyUser}.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = [
      codexPreview
      claudeCodeProxy
      piOpenAIOnly
      pkgs.bash
      pkgs.coreutils
      pkgs.fd
      pkgs.git
      pkgs.openssh
      pkgs.ripgrep
    ];
    environment = {
      HOME = t3Home;
      T3CODE_HOME = t3Home;
      CODEX_HOME = codexHome;
      PI_CODING_AGENT_DIR = piHome;
      T3_OPENAI_GATEWAY_KEY = "t3-openai-local";
      T3CODE_TELEMETRY_ENABLED = "false";
    };
    serviceConfig = {
      User = serviceUser;
      Group = serviceUser;
      WorkingDirectory = projectsDir;
      ExecStart = "${lib.getExe t3Preview} serve --mode web --no-browser --host 127.0.0.1 --port ${toString t3Port} --base-dir ${t3Home}";
      Restart = "on-failure";
      RestartSec = 5;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = "tmpfs";
      ProtectSystem = "strict";
      BindPaths = [ t3Home ];
      ReadWritePaths = [ t3Home ];
      UMask = "0077";

      # The mixed-account upstream also exposes Claude. Provider processes are
      # forced through the loopback allowlist gateway instead of reaching it.
      IPAddressDeny = [
        "100.66.163.218"
        "fd7a:115c:a1e0::3132:a3db"
      ];
      UnsetEnvironment = [
        "ANTHROPIC_API_KEY"
        "ANTHROPIC_AUTH_TOKEN"
        "CLAUDE_CODE_OAUTH_TOKEN"
      ];
    };
  };

  systemd.services."${serviceName}-tailscale-serve" = {
    description = "Publish the T3 v2 preview through Tailscale Serve";
    after = [
      "tailscaled.service"
      "${serviceName}.service"
    ];
    requires = [
      "tailscaled.service"
      "${serviceName}.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.tailscale ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      tailscale serve --bg --yes --https=443 http://127.0.0.1:${toString t3Port}
    '';
  };
}
