# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### System Configuration (NixOS)
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
# Bootstrap symlinks and directories
./bootstrap.sh

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

This is a complete NixOS-based development workstation configuration with:

### Core Components
- **nixos/flake.nix** - Main flake configuration defining system configurations and inputs
- **nixos/configuration.nix** - Shared system configuration with i3, development tools, and services
- **nixos/user.nix** - User configuration with packages, secrets, and environment variables
- **nixos/dev.nix** - Development environment with languages, LSPs, and tools
- **nixos/machines/{sietch,jacurutu}/default.nix** - Machine-specific configurations
- **bootstrap.sh** - Symlink dotfiles and create directory structure

### Directory Structure
- **conf/** - Application configurations (nvim, kitty, ghostty, etc.)
- **desktop/** - Desktop environment configs (i3, polybar, rofi, dunst)
- **bin/** - Utility scripts (sessionizer, polybar starter, pickers)
- **selfhost/** - Docker services (Open-WebUI, Jellyfin, Vaultwarden, Nginx)
- **nixos/modules/** - Reusable NixOS modules (agents, locale, systemd services, xbox controller)
- **nixos/machines/** - Machine-specific configurations (sietch with NVIDIA/CUDA, jacurutu with Framework laptop support)
- **nixos/desktop/** - Desktop environment modules (i3 window manager setup)
- **nixos/secrets/** - Encrypted secrets managed with agenix

### Key Features
- **Vault Storage**: `/vault` directory for persistent data with symlinks to `~/work`, `~/repos`, `~/journal`, `~/userdata`
- **Session Management**: `sessionizer` script for tmux session switching with fzf
- **AI Integration**: Multiple AI services configured (Anthropic, OpenAI, OpenRouter)
- **Development Environment**: Comprehensive LSP setup with Neovim, autocomplete, debugging, and code navigation
- **Self-Hosted Services**: Open-WebUI for AI chat, Jellyfin for media, Vaultwarden for passwords

### Configuration Management
- All configurations are symlinked via `bootstrap.sh`
- NixOS handles system packages and services declaratively using flakes
- Machine-specific settings isolated in `nixos/machines/{hostname}/`
- Development dependencies managed through Nix flakes
- Secrets encrypted with agenix and machine-specific SSH keys
- Custom packages (capscreen, dictator, diffgpt, dump, rollouts) integrated as flake inputs

### Development Workflow
1. Use `sessionizer` for project navigation
2. Neovim with comprehensive LSP setup for coding
3. Self-hosted AI services for assistance
4. Docker for service management
5. Git workflow with GitHub CLI integration

## Special Notes
- **sietch**: Desktop system with NVIDIA GPU and CUDA support, gaming setup
- **jacurutu**: Framework laptop with fingerprint support and power management
- Tailscale VPN integration for secure remote access
- Font requirement: FiraMono Nerd Font
- Default shell: bash with custom configuration
- Flake-based configuration for reproducible builds and easy rollbacks
