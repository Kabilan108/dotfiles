# Set up X11 and i3wm

{ pkgs, ... }:
let
  nomacs-configured = pkgs.symlinkJoin {
    name = "nomacs";
    paths = [ pkgs.nomacs ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/nomacs \
        --run "mkdir -p \$HOME/.config/nomacs" \
        --run "if [ ! -f \"\$HOME/.config/nomacs/Image Lounge.ini\" ]; then cp ${../config/nomacs.conf} \"\$HOME/.config/nomacs/Image Lounge.conf\"; chmod u+w \"\$HOME/.config/nomacs/Image Lounge.conf\"; fi"
    '';
  };
in
{
  imports = [
    ./apps/betterlockscreen.nix
    ./apps/dunst.nix
    ./apps/ghostty.nix
    ./apps/gtk.nix
    ./apps/i3.nix
    ./apps/picom.nix
    ./apps/polybar.nix
    ./apps/pwas.nix
    ./apps/rofi
    ./apps/zen
  ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [ "Noto Serif" ];
      sansSerif = [ "Noto Sans" ];
      monospace = [
        "FiraMono Nerd Font"
        "Fira Mono"
      ];
    };
  };

  home.file.".config/greenclip.toml".source = ../config/greenclip.toml;

  home.packages = with pkgs; [
    arandr
    autorandr
    betterlockscreen
    dunst
    evince
    feh
    flameshot
    light
    nerd-fonts.fira-mono
    networkmanagerapplet
    nomacs-configured
    picom
    pavucontrol
    playerctl
    pulseaudio
    rofi
    signal-desktop
    xclip
    xdotool
    xorg.xdpyinfo
    xorg.xev
    xorg.xrandr
  ];

  programs.pwas = {
    enable = true;
    apps = [
      {
        name = "Discord";
        url = "https://discord.com/channels/@me";
        icon = "discord";
        class = "Discord";
      }
      {
        name = "WhatsApp";
        url = "https://web.whatsapp.com";
        icon = "whatsapp";
        class = "WhatsApp";
      }
      {
        name = "Telegram";
        url = "https://web.telegram.org";
        icon = "telegram";
        class = "Telegram";
      }
    ];
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/*" = "org.nomacs.ImageLounge.desktop";

      "application/pdf" = "org.gnome.Evince.desktop";
      "application/epub+zip" = "org.gnome.Evince.desktop";
      "application/x-mobipocket-ebook" = "org.gnome.Evince.desktop";
      "application/vnd.comicbook+zip" = "org.gnome.Evince.desktop";
      "application/x-cbz" = "org.gnome.Evince.desktop";

      # default browser
      "application/xhtml+xml" = "zen-beta.desktop";
      "application/x-extension-htm" = "zen-beta.desktop";
      "application/x-extension-html" = "zen-beta.desktop";
      "application/x-extension-shtml" = "zen-beta.desktop";
      "application/x-extension-xht" = "zen-beta.desktop";
      "application/x-extension-xhtml" = "zen-beta.desktop";
      "text/html" = "zen-beta.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/mailto" = "zen-beta.desktop";

      # chromium
      "x-scheme-handler/chrome" = "chromium-browser.desktop";

      "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
      "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
    };
  };
}
