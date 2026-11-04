# The shell every fleet host shares: bash, tmux and the host's colors.
# sietch and jacurutu link the files into their ~/dotfiles checkouts and let
# tpm fetch tmux plugins. tleilax has no checkout: it gets Nix store copies
# and tmux plugins from nixpkgs.
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.shellBase;
  fleet = import ../../lib/fleet.nix;
  thisHost = osConfig.networking.hostName;
  host = fleet.hosts.${thisHost};

  configFile =
    name:
    if cfg.fromCheckout then
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/config/${name}"
    else
      ../../config + "/${name}";

  # Loaded in this order; continuum must come last.
  tmuxPlugins = with pkgs.tmuxPlugins; [
    {
      repo = "sainnhe/tmux-fzf";
      package = tmux-fzf;
    }
    {
      repo = "tmux-plugins/tmux-sensible";
      package = sensible;
    }
    {
      repo = "christoomey/vim-tmux-navigator";
      package = vim-tmux-navigator;
    }
    {
      repo = "tmux-plugins/tmux-copycat";
      package = copycat;
    }
    {
      repo = "tmux-plugins/tmux-open";
      package = open;
    }
    {
      repo = "tmux-plugins/tmux-resurrect";
      package = resurrect;
    }
    {
      repo = "tmux-plugins/tmux-continuum";
      package = continuum;
    }
  ];

  # tpm reads @plugin lines from files that ~/.tmux.conf sources.
  tpmPlugins = ''
    set -g @plugin 'tmux-plugins/tpm'
    ${lib.concatMapStrings (plugin: "set -g @plugin '${plugin.repo}'\n") tmuxPlugins}
    run '~/.tmux/plugins/tpm/tpm'
  '';
  nixpkgsPlugins = lib.concatMapStrings (plugin: "run-shell ${plugin.package.rtp}\n") tmuxPlugins;

  catppuccin =
    if cfg.fromCheckout then
      "~/.tmux/plugins/catppuccin/tmux"
    else
      "${pkgs.tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin";
in
{
  options.dotfiles.shellBase.fromCheckout = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Link config files into the ~/dotfiles checkout and let tpm fetch tmux
      plugins. When false, config files are Nix store copies and tmux plugins
      come from nixpkgs.
    '';
  };

  config = {
    programs.bash = {
      enable = true;
      initExtra = builtins.readFile ../../config/.bashrc;
    };

    home.packages = [ pkgs.tmux ];

    home.file.".tmux.conf".source = configFile ".tmux.conf";

    home.file.".config/tmux/theme.conf".text = ''
      source-file ${catppuccin}/catppuccin_options_tmux.conf
      source-file ${catppuccin}/catppuccin_tmux.conf
    '';

    home.file.".config/tmux/plugins.conf".text =
      if cfg.fromCheckout then tpmPlugins else nixpkgsPlugins;

    home.sessionVariables = {
      FLEET_HOST_ANSI = host.color.ansi;
      FLEET_HOST_HEX = host.color.hex;
    };

    home.file.".config/tmux/host.conf".text = ''
      set -g @host_color '${host.color.hex}'
      set -g pane-active-border-style 'fg=${host.color.hex}'
      set -g status-right '#[fg=#{@thm_yellow},bg=default]#{?client_prefix,PREFIX ,}#{?pane_in_mode,COPY ,}#{?window_zoomed_flag,ZOOM ,}#[bg=default] #[fg=#{@thm_crust},bg=${host.color.hex},bold] #S #[fg=${host.color.hex},bg=#{@thm_surface_0}] 󰒋 ${thisHost} '
    '';
  };
}
