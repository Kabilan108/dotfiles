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
  themeSource = pkgs.writeText "stillsuit-theme-v2.json" (builtins.toJSON canonical);
  validatedTheme =
    pkgs.runCommand "stillsuit-theme-v2-validated.json"
      {
        nativeBuildInputs = [ pkgs.check-jsonschema ];
      }
      ''
        check-jsonschema \
          --schemafile ${../../../packages/stillsuit-shell/schemas/theme.v2.json} \
          ${themeSource}
        cp ${themeSource} "$out"
      '';
  base16Projection = {
    scheme = "Stillsuit Catppuccin Mocha";
    author = "Catppuccin contributors; Stillsuit projection";
    variant = "dark";
    base00 = neutral.base;
    base01 = neutral.mantle;
    base02 = neutral.surface0;
    base03 = neutral.surface1;
    base04 = neutral.surface2;
    base05 = neutral.text;
    base06 = chromatic.rosewater;
    base07 = chromatic.lavender;
    base08 = chromatic.red;
    base09 = chromatic.peach;
    base0A = chromatic.yellow;
    base0B = chromatic.green;
    base0C = chromatic.teal;
    base0D = chromatic.blue;
    base0E = chromatic.magenta;
    base0F = chromatic.flamingo;
  };
in
{
  config = lib.mkMerge [
    {
      _module.args.stillsuitTheme = {
        inherit canonical validatedTheme;
      };
    }
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion =
            canonical.motion.fast < canonical.motion.normal && canonical.motion.normal < canonical.motion.slow;
          message = "programs.stillsuitShell canonical theme motion must satisfy fast < normal < slow";
        }
      ];

      xdg.configFile."stillsuit/theme.json".source = validatedTheme;

      stylix.base16Scheme = base16Projection;
    })
  ];
}
