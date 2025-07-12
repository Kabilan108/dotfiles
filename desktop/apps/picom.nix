{ ... }:
{
  services.picom = {
    enable = true;

    activeOpacity = 1.0;
    inactiveOpacity = 0.85;
    opacityRules = [
      "100:class_g = 'Brave-browser'"
    ];

    backend = "glx";
    fade = true;
    fadeDelta = 3;
    fadeExclude = [ ];
    vSync = true;

    settings = {
      # GLX backend settings
      glx-no-stencil = true;
      glx-copy-from-front = false;

      # Opacity settings
      frame-opacity = 1;
      inactive-opacity-override = false;

      # Fading settings
      no-fading-openclose = false;

      # Window detection and focus
      mark-wmwin-focused = true;
      mark-ovredir-focused = true;
      detect-rounded-corners = true;
      detect-client-opacity = true;
      detect-transient = true;
      detect-client-leader = true;

      # Performance settings
      refresh-rate = 0;
      dbe = false;
    };
  };
}
