{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.stillsuitShell;
  indexedPlugins = lib.imap0 (
    index: plugin:
    let
      manifestPath = "${toString plugin.source}/${plugin.manifestFile}";
      parsed =
        if builtins.pathExists manifestPath then
          builtins.tryEval (builtins.fromJSON (builtins.readFile manifestPath))
        else
          {
            success = false;
            value = null;
          };
      manifest = if parsed.success && builtins.isAttrs parsed.value then parsed.value else { };
      id = if builtins.isString (manifest.id or null) then manifest.id else "invalid-${toString index}";
      packageName =
        if builtins.isString id && builtins.match "^stillsuit(\\.[a-z][a-z0-9-]*)+$" id != null then
          lib.replaceStrings [ "." ] [ "-" ] id
        else
          "invalid-${toString index}";
      packageRoot = builtins.path {
        path = plugin.source;
        name = "stillsuit-plugin-${packageName}";
      };
    in
    plugin
    // {
      inherit
        index
        manifest
        manifestPath
        packageRoot
        parsed
        ;
      inherit id;
      storeManifestPath = "${packageRoot}/${plugin.manifestFile}";
    }
  ) cfg.plugins;
  enabledPlugins = lib.filter (plugin: plugin.enable) indexedPlugins;
  sortedPlugins = lib.sort (left: right: left.id < right.id) enabledPlugins;
  selectedBarOwner =
    if cfg.ownership.barOwners == [ ] then "external" else lib.head cfg.ownership.barOwners;
  selectedBar =
    if
      lib.elem selectedBarOwner [
        "external"
        "stillsuit.builtin-bar"
      ]
    then
      ""
    else
      selectedBarOwner;
  catalogData = {
    schemaVersion = 1;
    inherit selectedBar;
    plugins = map (plugin: {
      inherit (plugin) manifest packageRoot settings;
      enabled = true;
      sourceMode = "store";
    }) sortedPlugins;
  };
  catalogSource = pkgs.writeText "stillsuit-plugin-catalog.json" (builtins.toJSON catalogData);
  schema = ../../../packages/stillsuit-shell/schemas/manifest.v1.json;
  schemaChecks = lib.concatMapStringsSep "\n" (plugin: ''
    check-jsonschema --schemafile ${schema} ${lib.escapeShellArg plugin.storeManifestPath}
  '') enabledPlugins;
  catalog =
    pkgs.runCommand "stillsuit-plugin-catalog-validated.json"
      {
        nativeBuildInputs = [ pkgs.check-jsonschema ];
      }
      ''
        ${schemaChecks}
        cp ${catalogSource} "$out"
      '';
in
{
  config = lib.mkMerge [
    {
      _module.args.stillsuitRegistry = {
        inherit
          catalog
          catalogData
          enabledPlugins
          indexedPlugins
          sortedPlugins
          ;
      };
    }
    (lib.mkIf cfg.enable {
      xdg.configFile."stillsuit/catalog.json".source = catalog;
    })
  ];
}
