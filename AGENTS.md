# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### System Configuration (NixOS + Home Manager)
```bash
# Deploy system configuration using flakes
sudo nixos-rebuild switch --flake .#sietch
sudo nixos-rebuild switch --flake .#jacurutu

# Check flake syntax and structure
nix flake check --no-build

# Update flake inputs
nix flake update
```

### Dotfiles Setup
```bash
# Bootstrap symlinks and directories (for remaining non-Nix configs)
./scripts/bootstrap.sh

# Enter development shell with Claude Code
nix develop
```

### Self-Hosted Services
```bash
# Start all services
cd selfhost && docker-compose up -d

# View service logs
docker-compose logs -f [service-name]

# Stop services
docker-compose down
```

## Architecture Overview

This is a complete NixOS + Home Manager-based development workstation configuration with:

### Core Components
- **flake.nix** - Main flake configuration defining system configurations and inputs
- **configuration.nix** - Shared system configuration with services and basic setup
- **user.nix** - User configuration with Home Manager integration
- **home/default.nix** - Main Home Manager configuration (packages, programs, desktop)
- **home/shell.nix** - Shell environment and dotfiles
- **home/services.nix** - User systemd services
- **machines/{sietch,jacurutu}/default.nix** - Machine-specific configurations
- **scripts/bootstrap.sh** - Symlink remaining dotfiles and create directory structure

### Directory Structure
- **home/** - Home Manager configuration (shell, services, completions, desktop environments)
- **home/desktop/x11/** - X11 desktop environment (i3, polybar, rofi, dunst, picom)
- **home/desktop/wayland/** - Wayland desktop environment (future)
- **modules/home/** - Reusable Home Manager modules (fonts, ghostty, gtk, pwas, zen browser)
- **modules/nixos/** - Shared NixOS modules (desktop X11/Wayland, nvidia, VPN, virt-manager, etc.)
- **bin/** - Custom scripts and utilities
- **config/** - Application configurations (nvim, claude, vscode, etc.)
- **machines/** - Machine-specific configurations (sietch with NVIDIA/CUDA, jacurutu with Framework laptop support)
- **packages/** - Custom package definitions (cursor, nomacs-viewer)
- **wallpapers/** - Desktop wallpapers
- **selfhost/** - Docker services (Open-WebUI, Jellyfin, Vaultwarden, Nginx)
- **scripts/** - Utility scripts (bootstrap, partitioning)
- **secrets/** - Encrypted secrets managed with agenix

### Key Features
- **Vault Storage**: `/vault` directory for persistent data with symlinks to `~/work`, `~/repos`, `~/journal`, `~/userdata`
- **Session Management**: `sessionizer` script for tmux session switching with fzf
- **AI Integration**: Multiple AI services configured (Anthropic, OpenAI, OpenRouter)
- **Development Environment**: Comprehensive LSP setup with Neovim, autocomplete, debugging, and code navigation
- **Self-Hosted Services**: Open-WebUI for AI chat, Jellyfin for media, Vaultwarden for passwords

### Configuration Management
- **Home Manager**: User packages, programs, and dotfiles managed declaratively in `home/`
- **NixOS**: System services, hardware, and global configuration
- **Modular design**: Reusable modules in `modules/nixos/` and `modules/home/`
- **Display server support**: X11 and Wayland configurations in `home/desktop/`
- **Hybrid approach**: Some configs still symlinked via `scripts/bootstrap.sh` (legacy)
- Machine-specific settings isolated in `machines/{hostname}/`
- Development dependencies managed through Home Manager
- Secrets encrypted with agenix and machine-specific SSH keys
- Custom packages (capscreen, dictator, diffgpt, dump, rollouts) integrated as flake inputs
- Local packages (cursor, nomacs-viewer) defined in `packages/`

### Development Workflow
1. Use `sessionizer` for project navigation
2. Neovim with comprehensive LSP setup managed by Home Manager
3. Development tools (lazygit, lazydocker, etc.) configured via Home Manager
4. Self-hosted AI services for assistance
5. Docker for service management
6. Git workflow with GitHub CLI integration

## Special Notes
- **sietch**: Desktop system with NVIDIA GPU and CUDA support, gaming setup
- **jacurutu**: Framework laptop with fingerprint support and power management
- **Home Manager**: Manages user-level packages, programs, and configurations
- **Themes**: Catppuccin Mocha color scheme integrated across applications
- Tailscale VPN integration for secure remote access
- Font requirement: FiraMono Nerd Font (managed by Home Manager)
- Default shell: bash with custom configuration managed by Home Manager
- Flake-based configuration for reproducible builds and easy rollbacks

## Instructions

- When you make changes that necessitate rebuilding the flake, use `send-notify` to inform the user. Never attempt to rebuild the flake yourself.
- When making changes to my niri config `home/desktop/wayland/compositors/niri/config.kdl`, make sure to run `niri validate` and resolve any config errors.

