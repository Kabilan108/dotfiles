# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Development Environment
```bash
# Enter development shell with deploy-rs and Node.js
nix develop

# Install Claude Code (if not already available)
npm install -g @anthropic-ai/claude-code
```

### Server Deployment
```bash
# Deploy the heighliner server configuration
deploy .#heighliner

# Build the NixOS configuration locally (for testing)
nix build .#nixosConfigurations.heighliner.config.system.build.toplevel

# Check deployment configuration
nix flake check
```

### Image Building
```bash
# Build DigitalOcean image
cd images && nix-build digitalocean.nix
```

## Architecture Overview

This is a NixOS server deployment configuration using deploy-rs for automated deployments.

### Core Components
- **flake.nix** - Main deployment configuration with deploy-rs integration
- **heighliner-config.nix** - Complete NixOS server configuration for the "heighliner" host
- **images/digitalocean.nix** - DigitalOcean image builder for initial server setup

### Server Configuration (heighliner)
- **Base**: DigitalOcean NixOS droplet configuration
- **Services**: Nginx web server with test page, Docker with auto-pruning
- **Network**: Ports 22 (SSH), 80 (HTTP), 443 (HTTPS) open
- **Security**: SSH key-only authentication, root login via keys only
- **Dotfiles Integration**: Automatically clones and symlinks dotfiles from GitHub repo during activation

### Key Features
- **Automated Deployment**: deploy-rs handles remote deployments with rollback capability
- **Dotfiles Sync**: Root user automatically gets dotfiles (bash, git, tmux, neovim configs)
- **Development Tools**: Neovim as default editor, essential CLI tools pre-installed
- **Maintenance**: Automatic garbage collection and Docker pruning scheduled weekly

### Deployment Target
- **Hostname**: heighliner
- **User**: root (for system-level deployments)
- **Method**: SSH with deploy-rs activation scripts

The deployment system allows for safe, atomic updates to the remote server with the ability to rollback if needed.