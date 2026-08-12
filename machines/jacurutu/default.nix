{ pkgs, ... }:
let
  spotifyAudioCacheBytes = 2 * 1000 * 1000 * 1000;
in
{
  imports = [
    ./framework.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "jacurutu";

  services.pipewire.wireplumber.extraConfig."50-mic-volume" = {
    "wireplumber.settings" = {
      "device.routes.default-source-volume" = 0.30;
    };
  };

  environment = {
    systemPackages = with pkgs; [ fprintd ];
  };

  home-manager.users.kabilan = {
    dotfiles.services = {
      codex-desktop.enable = true;
      mic-volume-enforce.enable = true;
      moberg.eboostReviewerReport.enable = true;
      t3-code.enable = false;
      tracer-sync.enable = true;
    };

    programs.niri.config = null;
    services.spotifyd = {
      enable = true;
      settings.global = {
        autoplay = true;
        backend = "pulseaudio";
        bitrate = 320;
        cache_path = "/home/kabilan/.cache/spotifyd";
        dbus_type = "session";
        device_name = "jacurutu";
        device_type = "speaker";
        disable_discovery = true;
        max_cache_size = spotifyAudioCacheBytes;
        normalisation_pregain = 0.0;
        use_mpris = true;
        volume_normalisation = true;
      };
    };
    dotfiles.wallpaper.desktop = "$HOME/dotfiles/wallpapers/shoggoth-001.png";
    dotfiles.wallpaper.lockscreen = "$HOME/dotfiles/wallpapers/war-claude.png";
  };
}
