{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.stillsuitShell;
  canonical = import ../../../packages/stillsuit-shell/themes/catppuccin-mocha.nix;
  neutral = canonical.palette.neutral;
  chromatic = canonical.palette.chromatic;
  themeSource = pkgs.writeText "stillsuit-theme-v1.json" (builtins.toJSON canonical);
  validatedTheme =
    pkgs.runCommand "stillsuit-theme-v1-validated.json"
      {
        nativeBuildInputs = [ pkgs.check-jsonschema ];
      }
      ''
        check-jsonschema \
          --schemafile ${../../../packages/stillsuit-shell/schemas/theme.v1.json} \
          ${themeSource}
        cp ${themeSource} "$out"
      '';
  base16Projection = pkgs.writeText "stillsuit-catppuccin-mocha-base16.yaml" ''
    system: "base16"
    name: "Stillsuit Catppuccin Mocha"
    author: "Catppuccin contributors; Stillsuit projection"
    variant: "dark"
    palette:
      base00: "${neutral.base}"
      base01: "${neutral.mantle}"
      base02: "${neutral.surface0}"
      base03: "${neutral.surface1}"
      base04: "${neutral.surface2}"
      base05: "${neutral.text}"
      base06: "${chromatic.rosewater}"
      base07: "${chromatic.lavender}"
      base08: "${chromatic.red}"
      base09: "${chromatic.peach}"
      base0A: "${chromatic.yellow}"
      base0B: "${chromatic.green}"
      base0C: "${chromatic.teal}"
      base0D: "${chromatic.blue}"
      base0E: "${chromatic.magenta}"
      base0F: "${chromatic.flamingo}"
  '';
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          canonical.motion.fast <= canonical.motion.medium
          && canonical.motion.medium <= canonical.motion.slow;
        message = "programs.stillsuitShell canonical theme motion must satisfy fast <= medium <= slow";
      }
    ];

    xdg.configFile."stillsuit/theme.json".source = validatedTheme;

    # This projection is deliberately one-way. Stillsuit reads the semantic
    # record above; existing Stylix consumers receive only these 16 colors.
    stylix.base16Scheme = base16Projection;
  };
}
