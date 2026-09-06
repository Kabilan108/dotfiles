# Compile a rich palette into the public semantic and component records.
input:
let
  neutral = input.palette.neutral;
  chromatic = input.palette.chromatic;
  semantic = {
    background = {
      canvas = neutral.crust;
      desktop = neutral.base;
      scrim = neutral.scrim;
    };
    surface = {
      bar = neutral.mantle;
      panel = neutral.mantle;
      raised = neutral.surface0;
      overlay = neutral.base;
      hover = neutral.surface1;
      pressed = neutral.surface2;
      selected = chromatic.selection;
      danger = chromatic.dangerFill;
    };
    content = {
      primary = neutral.text;
      secondary = neutral.subtext1;
      muted = neutral.overlay1;
      disabled = neutral.overlay0;
      inverse = neutral.crust;
    };
    outline = {
      subtle = neutral.surface0;
      default = neutral.surface1;
      strong = neutral.overlay0;
      focus = chromatic.blue;
    };
    accent = {
      primary = chromatic.blue;
      hover = chromatic.accentHover;
      pressed = chromatic.accentPressed;
      subtle = chromatic.selection;
      onAccent = neutral.crust;
    };
    status = {
      info = chromatic.cyan;
      success = chromatic.green;
      warning = chromatic.yellow;
      danger = chromatic.red;
    };
    intensity = {
      normal = chromatic.green;
      elevated = chromatic.yellow;
      high = chromatic.peach;
      critical = chromatic.red;
    };
    signal = {
      audio = chromatic.green;
      microphone = chromatic.red;
      brightness = chromatic.yellow;
      charging = chromatic.peach;
      recording = chromatic.red;
    };
  };
in
input
// {
  inherit semantic;
  component = {
    bar = {
      background = semantic.surface.bar;
      border = semantic.outline.subtle;
      separator = semantic.outline.default;
      workspaceIdle = semantic.content.disabled;
      workspaceActive = semantic.accent.primary;
      clusterHover = semantic.surface.hover;
      clusterActive = semantic.surface.selected;
      clusterText = semantic.content.secondary;
      clusterActiveText = semantic.content.primary;
    };
    panel = {
      background = semantic.surface.panel;
      border = semantic.outline.default;
      section = semantic.surface.raised;
      rowHover = semantic.surface.hover;
      rowSelected = semantic.surface.selected;
      rowDanger = semantic.surface.danger;
      shadow = semantic.background.canvas;
    };
    control = {
      background = semantic.surface.raised;
      hover = semantic.surface.hover;
      pressed = semantic.surface.pressed;
      active = semantic.accent.primary;
      disabled = semantic.surface.panel;
      outline = semantic.outline.default;
      focus = semantic.outline.focus;
      text = semantic.content.primary;
      textDisabled = semantic.content.disabled;
      onActive = semantic.accent.onAccent;
    };
    notification = {
      background = semantic.surface.panel;
      border = semantic.outline.default;
      unread = semantic.accent.primary;
      info = semantic.accent.primary;
      inherit (semantic.status) success warning danger;
      muted = semantic.content.disabled;
    };
    osd = {
      border = semantic.outline.default;
      track = semantic.outline.default;
      fill = semantic.accent.primary;
      text = semantic.content.primary;
    };
  };
}
