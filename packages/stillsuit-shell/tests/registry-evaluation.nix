{
  pkgs,
  fixtureMode ? "valid",
}:
let
  inherit (pkgs) lib;
  assertionType = lib.types.submodule {
    options = {
      assertion = lib.mkOption { type = lib.types.bool; };
      message = lib.mkOption { type = lib.types.str; };
    };
  };
  pluginSource =
    if fixtureMode == "valid" then
      ../src
    else if fixtureMode == "malformed" then
      ./fixtures/malformed
    else
      throw "unknown registry fixture mode: ${fixtureMode}";
  manifestFile =
    if fixtureMode == "valid" then "plugins/builtin/clock/manifest.json" else "manifest.json";
  evaluated = lib.evalModules {
    specialArgs = { inherit pkgs; };
    modules = [
      ../../../modules/home/stillsuit/options.nix
      ../../../modules/home/stillsuit/registry.nix
      ../../../modules/home/stillsuit/assertions.nix
      (
        { stillsuitRegistry, ... }:
        {
          options.testRegistry = lib.mkOption { type = lib.types.raw; };
          config.testRegistry = stillsuitRegistry;
        }
      )
      {
        options = {
          assertions = lib.mkOption {
            type = lib.types.listOf assertionType;
            default = [ ];
          };
          xdg.configFile = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
          };
        };

        config.programs.stillsuitShell = {
          enable = true;
          ownership = {
            barOwners = [ "external" ];
            notificationOwners = [ "external" ];
          };
          plugins = [
            {
              source = pluginSource;
              inherit manifestFile;
            }
          ];
        };
      }
    ];
  };
  failures = lib.filter (assertion: !assertion.assertion) evaluated.config.assertions;
  registry = evaluated.config.testRegistry;
in
assert failures == [ ];
{
  inherit (registry) catalogData;
  pluginIds = map (plugin: plugin.id) registry.sortedPlugins;
}
