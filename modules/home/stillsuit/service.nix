{
  config,
  lib,
  pkgs,
  stillsuitRegistry,
  stillsuitTheme,
  ...
}:
let
  cfg = config.programs.stillsuitShell;
  agentPanelHelper = cfg.integrations.agentPanelHelperPackage;
  exactRuntimeInputs = cfg.runtimeInputs ++ lib.optional (agentPanelHelper != null) agentPanelHelper;
  localMode = cfg.development.sourceMode == "local";
  localSource = toString cfg.development.localSource;
  executable = if localMode then lib.getExe pkgs.quickshell else lib.getExe cfg.package;
  arguments = lib.optionals localMode [ "--no-duplicate" ] ++ [
    "--no-color"
    "--verbose"
    "--config"
    cfg.configId
  ];
  configSource =
    if localMode then
      config.lib.file.mkOutOfStoreSymlink localSource
    else
      "${cfg.package}/share/stillsuit-shell/src";
  agentPanelDefaults = pkgs.writeText "stillsuit-agent-panel-defaults.json" (
    builtins.toJSON cfg.integrations.agentPanelDefaults
  );
  agentPanelConfig = "${config.xdg.configHome}/stillsuit/agent-panel.json";
  pluginHelper = pkgs.callPackage ../../../packages/stillsuit-shell/plugin-helper.nix { };
  workbench = pkgs.callPackage ../../../packages/stillsuit-shell/workbench-helper.nix {
    stillsuit-shell = cfg.package;
    stillsuit-plugins = pluginHelper;
  };
  runtimeDiscovery = pkgs.writeText "stillsuit-runtime-discovery.json" (
    builtins.toJSON {
      seed = toString stillsuitRegistry.discoverySeed;
      roots = cfg.pluginRoots;
      state = "${config.xdg.stateHome}/stillsuit";
      core = "${cfg.package}/share/stillsuit-shell/src";
      schema = "${cfg.package}/share/stillsuit-shell/schemas/manifest.v1.json";
      preferences = "${config.xdg.configHome}/stillsuit/plugins.json";
    }
  );
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages =
          (if localMode then [ pkgs.quickshell ] else [ cfg.package ])
          ++ lib.optional (cfg.pluginRoots != [ ]) pluginHelper
          ++ lib.optional cfg.workbench.enable workbench
          ++ lib.optional (agentPanelHelper != null) agentPanelHelper;

        xdg.configFile."quickshell/${cfg.configId}".source = configSource;
        xdg.configFile."stillsuit/runtime-discovery.json" = lib.mkIf (cfg.pluginRoots != [ ]) {
          source = runtimeDiscovery;
        };

        systemd.user.services.stillsuit-shell = {
          Unit = {
            Description = "Stillsuit desktop shell";
            Documentation = "file://${cfg.package}/share/stillsuit-shell/docs/host-contract.md";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };

          Service = {
            Type = "simple";
            ExecStart = lib.escapeShellArgs ([ executable ] ++ arguments);
            Restart = "on-failure";
            RestartSec = 2;
            # Keep informational shell logs across restarts in the journal.
            # configuration.nix bounds the shared journal to 14 days, 1 GiB
            # persistent / 256 MiB runtime. No unbounded per-service copy.
            # Read with: journalctl --user -u stillsuit-shell --since '14 days ago'
            StandardOutput = "journal";
            StandardError = "journal";
            SyslogIdentifier = "stillsuit-shell";
            TimeoutStopSec = 10;
            RuntimeDirectory = "stillsuit";
            StateDirectory = "stillsuit";
            Environment = [
              "PATH=${lib.makeBinPath exactRuntimeInputs}"
              "STILLSUIT_CATALOG_PATH=${stillsuitRegistry.catalog}"
              "STILLSUIT_CONFIG_ID=${cfg.configId}"
              "STILLSUIT_THEME_PATH=${stillsuitTheme.validatedTheme}"
              "STILLSUIT_ALLOW_LOCAL_PLUGINS=${if localMode || cfg.pluginRoots != [ ] then "1" else "0"}"
              "STILLSUIT_SHADOW_MODE=${if cfg.development.shadowMode then "1" else "0"}"
            ]
            ++ lib.optionals (cfg.pluginRoots != [ ]) [
              "STILLSUIT_PLUGIN_RUNTIME_CONFIG=${runtimeDiscovery}"
              "STILLSUIT_PLUGIN_HELPER=${lib.getExe pluginHelper}"
              "QML_IMPORT_PATH=${cfg.package}/share/stillsuit-shell/qml"
            ]
            ++ lib.optional (agentPanelHelper != null) (
              "STILLSUIT_AGENT_PANEL_HELPER=${lib.getExe agentPanelHelper}"
            );
          };

          Install.WantedBy = [ "graphical-session.target" ];
        };
      }
      (lib.mkIf (agentPanelHelper != null) {
        home.activation.stillsuitAgentPanelDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ ! -e ${lib.escapeShellArg agentPanelConfig} ]; then
            ${lib.getExe' pkgs.coreutils "install"} -Dm0600 \
              ${agentPanelDefaults} ${lib.escapeShellArg agentPanelConfig}
          fi
        '';
      })
    ]
  );
}
