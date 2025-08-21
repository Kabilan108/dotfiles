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
- **common/user.nix** - User configuration with Home Manager integration
- **dev/default.nix** - Development environment configuration with packages and programs
- **desktop/default.nix** - Desktop environment configuration via Home Manager
- **machines/{sietch,jacurutu}/default.nix** - Machine-specific configurations
- **scripts/bootstrap.sh** - Symlink remaining dotfiles and create directory structure

### Directory Structure
- **dev/** - Development environment and user configuration (Home Manager: packages, programs, dotfiles, custom scripts)
- **desktop/** - Desktop environment configs (i3, polybar, rofi, dunst) managed declaratively by Home Manager
- **common/** - Shared NixOS modules (user config, desktop X11, nvidia, etc.)
- **machines/** - Machine-specific configurations (sietch with NVIDIA/CUDA, jacurutu with Framework laptop support)
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
- **Home Manager**: User packages, programs, and dotfiles managed declaratively
- **NixOS**: System services, hardware, and global configuration
- **Hybrid approach**: Some configs still symlinked via `scripts/bootstrap.sh` (legacy)
- Machine-specific settings isolated in `machines/{hostname}/`
- Development dependencies managed through Home Manager
- Secrets encrypted with agenix and machine-specific SSH keys
- Custom packages (capscreen, dictator, diffgpt, dump, rollouts) integrated as flake inputs

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
