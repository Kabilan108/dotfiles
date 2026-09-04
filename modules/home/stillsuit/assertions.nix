{
  config,
  lib,
  stillsuitRegistry,
  ...
}:
let
  cfg = config.programs.stillsuitShell;
  inherit (stillsuitRegistry) enabledPlugins indexedPlugins;
  allowedKinds = [
    "bar"
    "bar-widget"
    "service"
    "panel"
    "overlay"
    "menu"
  ];
  allowedManifestKeys = [
    "apiVersion"
    "barWidget"
    "capabilities"
    "dependencies"
    "description"
    "entryPoints"
    "id"
    "keepLoaded"
    "kinds"
    "name"
    "schemaVersion"
    "scope"
    "stateSchemaVersion"
    "version"
  ];
  requiredManifestKeys = [
    "schemaVersion"
    "id"
    "name"
    "version"
    "apiVersion"
    "kinds"
    "entryPoints"
    "scope"
  ];
  kindFields = {
    bar = "bar";
    "bar-widget" = "barWidget";
    service = "service";
    panel = "panel";
    overlay = "overlay";
    menu = "menu";
  };
  validRelativePath =
    path: value:
    builtins.isString value
    && builtins.match "^[A-Za-z0-9][A-Za-z0-9._/-]*\\.qml$" value != null
    && !lib.hasPrefix "/" value
    && !lib.hasInfix "//" value
    && !lib.elem ".." (lib.splitString "/" value)
    && builtins.pathExists "${toString path}/${value}";
  validManifestFile =
    plugin:
    builtins.match "^[A-Za-z0-9][A-Za-z0-9._/-]*\\.json$" plugin.manifestFile != null
    && !lib.hasPrefix "/" plugin.manifestFile
    && !lib.hasInfix "//" plugin.manifestFile
    && !lib.elem ".." (lib.splitString "/" plugin.manifestFile);
  validManifest =
    plugin:
    let
      manifest = plugin.manifest;
      keys = builtins.attrNames manifest;
      kinds = manifest.kinds or [ ];
      entryPoints = manifest.entryPoints or { };
      scope = manifest.scope or { };
      hasKindContract =
        kind:
        let
          field = kindFields.${kind};
          validScope =
            if kind == "service" then
              scope.${field} or null == "global"
            else if
              lib.elem kind [
                "bar"
                "bar-widget"
              ]
            then
              scope.${field} or null == "per-output"
            else
              lib.elem (scope.${field} or null) [
                "global"
                "per-output"
              ];
        in
        builtins.hasAttr field entryPoints
        && validRelativePath plugin.manifestRoot entryPoints.${field}
        && validScope;
    in
    plugin.manifestExists
    && builtins.isAttrs plugin.manifestValue
    && builtins.isAttrs manifest
    && lib.all (key: builtins.hasAttr key manifest) requiredManifestKeys
    && lib.all (key: lib.elem key allowedManifestKeys) keys
    && manifest.schemaVersion or null == 1
    && manifest.apiVersion or null == "1"
    && builtins.isString (manifest.id or null)
    && builtins.match "^stillsuit(\\.[a-z][a-z0-9-]*)+$" (manifest.id or "") != null
    && builtins.isString (manifest.name or null)
    && manifest.name != ""
    && builtins.isString (manifest.version or null)
    && builtins.match "^[0-9]+\\.[0-9]+\\.[0-9]+([+-][0-9A-Za-z.-]+)?$" (manifest.version or "") != null
    && builtins.isList kinds
    && kinds != [ ]
    && lib.length kinds == lib.length (lib.unique kinds)
    && lib.all (kind: lib.elem kind allowedKinds) kinds
    && builtins.isAttrs entryPoints
    && builtins.isAttrs scope
    && lib.all hasKindContract kinds
    && lib.all (field: lib.elem field (map (kind: kindFields.${kind}) kinds)) (
      builtins.attrNames entryPoints
    )
    && lib.all (field: lib.elem field (map (kind: kindFields.${kind}) kinds)) (
      builtins.attrNames scope
    );
  ids = map (plugin: plugin.id) enabledPlugins;
  findPlugin = owner: lib.findFirst (plugin: plugin.id == owner) null enabledPlugins;
  validBarOwner =
    owner:
    let
      plugin = findPlugin owner;
    in
    owner == "external"
    || owner == "stillsuit.builtin-bar"
    || (plugin != null && lib.elem "bar" (plugin.manifest.kinds or [ ]));
  validNotificationOwner =
    owner:
    let
      plugin = findPlugin owner;
    in
    owner == "external"
    || (
      plugin != null
      && lib.elem "service" (plugin.manifest.kinds or [ ])
      && lib.elem "notification-server" (plugin.manifest.capabilities or [ ])
    );
  pluginAssertions = lib.concatMap (plugin: [
    {
      assertion = validManifestFile plugin;
      message = "programs.stillsuitShell plugin ${toString plugin.index} has an unsafe manifestFile path";
    }
    {
      assertion = plugin.manifestExists;
      message = "programs.stillsuitShell plugin ${toString plugin.index} manifest is missing: ${plugin.manifestPath}";
    }
    {
      assertion = !plugin.manifestExists || builtins.isAttrs plugin.manifestValue;
      message = "programs.stillsuitShell plugin ${toString plugin.index} manifest must contain a JSON object: ${plugin.manifestPath}";
    }
    {
      assertion = validManifest plugin;
      message = "programs.stillsuitShell plugin ${toString plugin.index} violates manifest.v1, API v1, or entry-point containment";
    }
  ]) indexedPlugins;
in
{
  config = lib.mkIf cfg.enable {
    assertions = pluginAssertions ++ [
      {
        assertion = lib.length cfg.ownership.barOwners == 1;
        message = "programs.stillsuitShell must select exactly one bar owner";
      }
      {
        assertion = lib.length cfg.ownership.notificationOwners == 1;
        message = "programs.stillsuitShell must select exactly one notification owner";
      }
      {
        assertion = lib.length ids == lib.length (lib.unique ids);
        message = "programs.stillsuitShell plugin IDs must be unique";
      }
      {
        assertion = lib.all validBarOwner cfg.ownership.barOwners;
        message = "programs.stillsuitShell bar owner must be external, stillsuit.builtin-bar, or an enabled plugin ID";
      }
      {
        assertion = lib.all validNotificationOwner cfg.ownership.notificationOwners;
        message = "programs.stillsuitShell notification owner must be external or an enabled service plugin declaring the notification-server capability";
      }
      {
        assertion = cfg.development.sourceMode != "local" || cfg.development.localSource != null;
        message = "programs.stillsuitShell.development.localSource is required in local source mode";
      }
    ];
  };
}
