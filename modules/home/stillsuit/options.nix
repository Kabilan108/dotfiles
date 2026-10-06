{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  # Session actions run directly from the shell, whose PATH holds only the
  # exact runtime inputs, so the program must be an absolute path.
  sessionArgv =
    types.addCheck (types.listOf types.str) (
      argv: argv == [ ] || lib.hasPrefix "/" (builtins.head argv)
    )
    // {
      description = "empty list, or list of string whose first element is an absolute path";
    };
  systemctl = lib.getExe' pkgs.systemd "systemctl";
  loginctl = lib.getExe' pkgs.systemd "loginctl";
  sessionOption =
    action: default: defaultText:
    mkOption {
      type = sessionArgv;
      inherit default;
      defaultText = lib.literalExpression defaultText;
      description = "Argv for the ${action} session action; the program must be an absolute path. Empty disables it.";
    };
  pluginType = types.submodule {
    options = {
      source = mkOption {
        type = types.path;
        description = "Immutable plugin package root containing its manifest and QML entry points.";
      };

      manifestFile = mkOption {
        type = types.str;
        default = "manifest.json";
        description = ''
          Relative manifest path below the immutable source tree. Entry points
          are resolved from the manifest's directory, which may be nested.
        '';
      };

      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether the generated catalog enables this plugin.";
      };

      settings = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Read-only settings injected into this plugin by the host.";
      };
    };
  };
in
{
  options.programs.stillsuitShell = {
    enable = lib.mkEnableOption "the Stillsuit Quickshell host";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../../../packages/stillsuit-shell/default.nix {
        # wl-copy and wl-paste exec `cat` to move clipboard data.
        runtimeInputs =
          config.programs.stillsuitShell.runtimeInputs
          ++ [
            pkgs.coreutils
            pkgs.wl-clipboard
          ]
          ++ lib.optional (
            config.programs.stillsuitShell.integrations.agentPanelHelperPackage != null
          ) config.programs.stillsuitShell.integrations.agentPanelHelperPackage;
      };
      defaultText = lib.literalExpression ''
        pkgs.callPackage ../../../packages/stillsuit-shell/default.nix {
          runtimeInputs = cfg.runtimeInputs ++ [ pkgs.coreutils pkgs.wl-clipboard ] ++ lib.optional
            (cfg.integrations.agentPanelHelperPackage != null)
            cfg.integrations.agentPanelHelperPackage;
        }
      '';
      description = "Stillsuit shell package used in store source mode.";
    };

    configId = mkOption {
      type = types.strMatching "^[a-z][a-z0-9-]*$";
      default = "stillsuit-next";
      description = "Stable production configuration identity used by logs and IPC status.";
    };

    plugins = mkOption {
      type = types.listOf pluginType;
      default = [ ];
      description = "Reviewed plugin roots included in the deterministic store-backed catalog.";
    };

    pluginRoots = mkOption {
      type = types.listOf (types.strMatching "^/.*");
      default = [ ];
      description = ''
        Trusted filesystem plugin directories, in precedence order. Each child
        directory contains manifest.json. The core bar remains packaged.
        An empty list retains the generated catalog for isolated installations.
      '';
    };

    profiles = {
      definitionsPath = mkOption {
        type = types.strMatching "^/.*";
        default = "${config.xdg.configHome}/stillsuit/profiles.json";
        description = "Mutable named plugin profile definitions read by the runtime helper.";
      };

      activeProfilePath = mkOption {
        type = types.strMatching "^/.*";
        default = "${config.xdg.stateHome}/stillsuit/active-profile.json";
        description = "Mutable state file containing the selected plugin profile.";
      };

      requiredPluginIds = mkOption {
        type = types.listOf (types.strMatching "^stillsuit(\\.[a-z][a-z0-9-]*)+$");
        default = [ ];
        description = ''
          Enabled plugins that every profile must retain. The runtime also
          protects the selected bar and notification owners.
        '';
      };
    };

    ownership = {
      barOwners = mkOption {
        type = types.listOf types.str;
        default = [ "external" ];
        description = "The single exclusion-zone owner: external, stillsuit.builtin-bar, or an enabled bar plugin ID.";
      };

      notificationOwners = mkOption {
        type = types.listOf types.str;
        default = [ "external" ];
        description = "The single notification D-Bus owner: external or an enabled Stillsuit plugin ID.";
      };
    };

    runtimeInputs = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = ''
        Exact binaries exposed to in-process QML. Keep this list empty unless
        reviewed plugin code invokes a fixed helper. Lane C adds its agent-panel
        helper package here during integration; it must not add an ambient PATH.
      '';
    };

    launch = {
      terminal = mkOption {
        type = types.nonEmptyListOf types.str;
        default = [
          "ghostty"
          "-e"
        ];
        description = ''
          Argv prefix for desktop entries with Terminal=true. The entry's
          command is appended. Resolved against the session PATH.
        '';
      };

      browser = mkOption {
        type = types.nonEmptyListOf types.str;
        default = [ "xdg-open" ];
        description = "Argv prefix that opens an http or https URL, which is appended. Resolved against the session PATH.";
      };

      opener = mkOption {
        type = types.nonEmptyListOf types.str;
        default = [ "xdg-open" ];
        description = "Argv prefix that opens a file or directory path, which is appended. Resolved against the session PATH.";
      };

      session = mkOption {
        type = types.submodule {
          options = {
            lock = sessionOption "lock" [
              loginctl
              "lock-session"
            ] ''[ (lib.getExe' pkgs.systemd "loginctl") "lock-session" ]'';
            suspend = sessionOption "suspend" [
              systemctl
              "suspend"
            ] ''[ (lib.getExe' pkgs.systemd "systemctl") "suspend" ]'';
            logout = sessionOption "logout" [ ] "[ ]";
            reboot = sessionOption "reboot" [
              systemctl
              "reboot"
            ] ''[ (lib.getExe' pkgs.systemd "systemctl") "reboot" ]'';
            poweroff = sessionOption "poweroff" [
              systemctl
              "poweroff"
            ] ''[ (lib.getExe' pkgs.systemd "systemctl") "poweroff" ]'';
          };
        };
        default = { };
        description = ''
          Session actions offered to plugins through context.actions.sessionAction.
          They run detached from the shell, not in an app scope.
        '';
      };
    };

    workbench.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Install stillsuit-workbench, the fixture-backed plugin workbench on a nested compositor.";
    };

    integrations.agentPanelHelperPackage = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        Lane C integration point. The package must provide only the fixed
        stillsuit-agent-panel executable and its declared runtime closure.
        Setting this adds it to the shell's exact PATH; null adds no stub.
      '';
    };

    integrations.agentPanelDefaults = {
      command = mkOption {
        type = types.nonEmptyListOf types.str;
        default = [
          "codex"
          "--yolo"
          "--model"
          "gpt-5.6-sol"
          "--config"
          "model_reasoning_effort=low"
          "--config"
          "service_tier=fast"
        ];
        description = ''
          Initial agent command as an argv list, run inside the panel's tmux
          session. Written only when the runtime configuration is absent; edit
          ~/.config/stillsuit/agent-panel.json to change it without a rebuild.
        '';
      };

      workingDirectory = mkOption {
        type = types.str;
        default = "~/dotfiles";
        description = "Initial working directory for the agent; `~` expands to HOME.";
      };
    };

    development = {
      sourceMode = mkOption {
        type = types.enum [
          "store"
          "local"
        ];
        default = "store";
        description = "Use the immutable package source in production or an explicit local tree for development.";
      };

      localSource = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Local shell source used only when sourceMode is local.";
      };

      shadowMode = mkOption {
        type = types.bool;
        default = false;
        description = "Disable production surface and service authority for isolated preview runs.";
      };
    };
  };
}
