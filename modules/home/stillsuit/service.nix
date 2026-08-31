{
  config,
  lib,
  pkgs,
  stillsuitRegistry,
  ...
}:
let
  cfg = config.programs.stillsuitShell;
  exactRuntimeInputs =
    cfg.runtimeInputs
    ++ lib.optional (
      cfg.integrations.agentPanelHelperPackage != null
    ) cfg.integrations.agentPanelHelperPackage;
  localMode = cfg.development.sourceMode == "local";
  localSource = toString cfg.development.localSource;
  executable = if localMode then lib.getExe pkgs.quickshell else lib.getExe cfg.package;
  arguments = lib.optionals localMode [
    "--no-duplicate"
    "--path"
    localSource
  ];
in
{
  config = lib.mkIf cfg.enable {
    home.packages = if localMode then [ pkgs.quickshell ] else [ cfg.package ];

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
        TimeoutStopSec = 10;
        Environment = [
          "PATH=${lib.makeBinPath exactRuntimeInputs}"
          "STILLSUIT_CATALOG=${stillsuitRegistry.catalog}"
          "STILLSUIT_CONFIG_ID=${cfg.configId}"
          "STILLSUIT_THEME=%h/.config/stillsuit/theme.json"
        ];
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
