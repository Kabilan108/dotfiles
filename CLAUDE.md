# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### System Configuration (NixOS)
```bash
# Deploy system configuration
sudo nixos-rebuild switch
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
- **nixos/configuration.nix** - Main system configuration with i3, development tools, and services
- **nixos/machine.nix** - Machine-specific settings (hostname: "sietch", NVIDIA enabled)
- **flake.nix** - Development shell with Node.js and Claude Code CLI
- **bootstrap.sh** - Symlink dotfiles and create directory structure

### Directory Structure
- **conf/** - Application configurations (nvim, kitty, ghostty, etc.)
- **desktop/** - Desktop environment configs (i3, polybar, rofi, dunst)
- **bin/** - Utility scripts (sessionizer, polybar starter, pickers)
- **selfhost/** - Docker services (Open-WebUI, Jellyfin, Vaultwarden, Nginx)
- **nixos/modules/** - Reusable NixOS modules (i3 setup, NVIDIA support)

### Key Features
- **Vault Storage**: `/vault` directory for persistent data with symlinks to `~/work`, `~/repos`, `~/journal`, `~/userdata`
- **Session Management**: `sessionizer` script for tmux session switching with fzf
- **AI Integration**: Multiple AI services configured (Anthropic, OpenAI, OpenRouter)
- **Development Environment**: Comprehensive LSP setup with Neovim, autocomplete, debugging, and code navigation
- **Self-Hosted Services**: Open-WebUI for AI chat, Jellyfin for media, Vaultwarden for passwords

### Configuration Management
- All configurations are symlinked via `bootstrap.sh`
- NixOS handles system packages and services declaratively
- Machine-specific settings isolated in `machine.nix`
- Development dependencies managed through Nix flakes

### Development Workflow
1. Use `sessionizer` for project navigation
2. Neovim with comprehensive LSP setup for coding
3. Self-hosted AI services for assistance
4. Docker for service management
5. Git workflow with GitHub CLI integration

## Special Notes
- System uses NVIDIA GPU with CUDA support when `enableNvidia = true`
- Tailscale VPN integration for secure remote access
- Font requirement: FiraMono Nerd Font
- Default shell: bash with custom configuration
