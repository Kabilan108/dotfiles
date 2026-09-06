# Explicit adapter for an imported Base16 scheme. Rich themes bypass this
# lossy adapter and supply their own neutral and chromatic ramps to compile.nix.
{
  scheme,
  baseline ? import ./catppuccin-mocha.nix,
}:
let
  color = value: if builtins.substring 0 1 value == "#" then value else "#${value}";
  p = builtins.mapAttrs (_: value: color value) (
    builtins.intersectAttrs {
      base00 = null;
      base01 = null;
      base02 = null;
      base03 = null;
      base04 = null;
      base05 = null;
      base06 = null;
      base07 = null;
      base08 = null;
      base09 = null;
      base0A = null;
      base0B = null;
      base0C = null;
      base0D = null;
      base0E = null;
      base0F = null;
    } scheme
  );
in
import ./compile.nix (
  baseline
  // {
    identity = baseline.identity // {
      id = "stillsuit.base16";
      name = scheme.scheme or "Base16";
      mode = scheme.variant or "dark";
      description = "Imported Base16 palette with derived Stillsuit roles.";
    };
    palette = {
      neutral = {
        crust = p.base00;
        scrim = p.base00;
        mantle = p.base00;
        base = p.base00;
        surface0 = p.base01;
        surface1 = p.base02;
        surface2 = p.base03;
        overlay0 = p.base03;
        overlay1 = p.base04;
        overlay2 = p.base04;
        subtext0 = p.base04;
        subtext1 = p.base06;
        text = p.base05;
      };
      chromatic = {
        rosewater = p.base06;
        flamingo = p.base0F;
        pink = p.base0E;
        magenta = p.base0E;
        red = p.base08;
        maroon = p.base08;
        peach = p.base09;
        yellow = p.base0A;
        green = p.base0B;
        teal = p.base0C;
        cyan = p.base0C;
        sapphire = p.base0D;
        blue = p.base0D;
        lavender = p.base07;
        selection = p.base02;
        accentHover = p.base0D;
        accentPressed = p.base0D;
        dangerFill = p.base01;
      };
    };
  }
)
