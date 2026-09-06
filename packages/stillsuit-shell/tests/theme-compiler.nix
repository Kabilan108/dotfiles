let
  baseline = import ../themes/catppuccin-mocha.nix;
  changed = import ../themes/compile.nix (
    baseline
    // {
      palette = baseline.palette // {
        chromatic = baseline.palette.chromatic // {
          blue = "#123456";
        };
      };
    }
  );
  imported = import ../themes/from-base16.nix {
    scheme = {
      base00 = "101010";
      base01 = "202020";
      base02 = "303030";
      base03 = "404040";
      base04 = "505050";
      base05 = "dddddd";
      base06 = "eeeeee";
      base07 = "ffffff";
      base08 = "ff0000";
      base09 = "ff8800";
      base0A = "ffff00";
      base0B = "00ff00";
      base0C = "00ffff";
      base0D = "0000ff";
      base0E = "ff00ff";
      base0F = "880000";
    };
  };
in
assert changed.semantic.accent.primary == "#123456";
assert changed.component.control.active == "#123456";
assert changed.component.bar.workspaceActive == "#123456";
assert changed.component.panel.background == changed.semantic.surface.panel;
assert imported.semantic.intensity.high == "#ff8800";
assert imported.component.bar.background == "#101010";
assert !(baseline.component ? resources);
true
