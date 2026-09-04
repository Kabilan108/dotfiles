{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
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
        runtimeInputs =
          config.programs.stillsuitShell.runtimeInputs
          ++ lib.optional (
            config.programs.stillsuitShell.integrations.agentPanelHelperPackage != null
          ) config.programs.stillsuitShell.integrations.agentPanelHelperPackage;
      };
      defaultText = lib.literalExpression ''
        pkgs.callPackage ../../../packages/stillsuit-shell/default.nix {
          runtimeInputs = cfg.runtimeInputs ++ lib.optional
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
      model = mkOption {
        type = types.enum [
          "gpt-5.6-sol"
          "gpt-5.6-terra"
          "gpt-5.6-luna"
        ];
        default = "gpt-5.6-sol";
        description = "Initial agent-panel model, written only when its runtime configuration is absent.";
      };

      reasoningEffort = mkOption {
        type = types.enum [
          "low"
          "medium"
          "high"
          "xhigh"
          "max"
          "ultra"
        ];
        default = "low";
        description = "Initial agent-panel reasoning effort, written only when its runtime configuration is absent.";
      };

      serviceTier = mkOption {
        type = types.enum [
          "fast"
          "priority"
        ];
        default = "fast";
        description = "Initial agent-panel service tier, written only when its runtime configuration is absent.";
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
