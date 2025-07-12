# NixOS + Home Manager Flake Configuration

A modular, flake-based NixOS configuration with Home Manager integration, supporting multiple machines with shared and machine-specific settings.

## Quick Start

```bash
# Deploy to specific machine
sudo nixos-rebuild switch --flake .#sietch
sudo nixos-rebuild switch --flake .#jacurutu

# Check configuration
nix flake check --no-build

# Update inputs
nix flake update
```

## Architecture

### Flake Structure

```
├── flake.nix                 # Main flake definition
├── flake.lock               # Pinned input versions
├── configuration.nix        # Shared system configuration
├── secrets.nix              # Agenix secrets configuration
├── dev/                     # Development environment (Home Manager)
│   ├── default.nix          # User packages, programs, and dotfiles
│   ├── systemd-services.nix # User systemd services
│   ├── bin/                 # Custom scripts and utilities
│   └── config/              # Application configurations
│       ├── nvim/            # Neovim configuration
│       ├── claude/          # Claude Code settings
│       ├── vscode/          # VSCode configuration
│       └── ...              # Other app configs
├── desktop/                 # Desktop environment (Home Manager)
│   ├── default.nix          # i3, polybar, rofi, dunst setup
│   ├── apps/                # Desktop app configurations (Nix)
│   │   ├── rofi/            # Rofi launcher configuration
│   │   ├── dunst.nix        # Notification daemon setup
│   │   ├── picom.nix        # Compositor configuration
│   │   └── polybar.nix      # Status bar configuration
│   └── wallpapers/          # Desktop wallpapers
├── common/                  # Shared NixOS modules
│   ├── user.nix             # User configuration with Home Manager
│   ├── desktop-x11.nix      # X11 and desktop services
│   ├── nvidia.nix           # NVIDIA/CUDA setup
│   └── xbox-controller.nix  # Gaming controller support
├── machines/                # Machine-specific configurations
│   ├── sietch/
│   │   ├── default.nix      # Desktop system config
│   │   └── hardware-configuration.nix
│   └── jacurutu/
│       ├── default.nix      # Framework laptop config
│       └── hardware-configuration.nix
├── scripts/                 # Utility scripts
│   ├── bootstrap.sh         # Legacy dotfile symlinks
│   └── partitioning.sh      # Disk partitioning helper
├── selfhost/                # Docker services
│   └── compose.yml          # Open-WebUI, Jellyfin, etc.
└── secrets/                 # Encrypted secrets (agenix)
    └── env.age              # Environment variables
```

### Machines

#### sietch (Desktop)
- **Role**: Primary desktop workstation
- **Hardware**: NVIDIA GPU with CUDA support
- **Features**:
  - Gaming setup (Steam, controller support)
  - NVIDIA drivers and container toolkit
  - OpenRGB for RGB control
  - SSH server enabled
  - Development environment
  - Docker with GPU support

#### jacurutu (Laptop)
- **Role**: Portable development machine
- **Hardware**: Framework laptop
- **Features**:
  - Fingerprint authentication
  - Power management optimizations
  - Portable development setup
  - Framework-specific hardware support

## Key Features

### Shared Configuration
- **Home Manager**: User-level package and configuration management
- **i3 Window Manager**: Tiling window manager with custom keybindings (via Home Manager)
- **Desktop Applications**: Fully declarative configuration for rofi, dunst, picom, polybar, and GTK themes
- **Development Environment**: Comprehensive LSP setup, languages, and tools (via Home Manager)
- **Audio**: PipeWire with PulseAudio compatibility
- **Networking**: NetworkManager with VPN support
- **Security**: Tailscale VPN, encrypted secrets via agenix
- **Themes**: Catppuccin Mocha color scheme integrated across applications

### Custom Packages
All custom packages are integrated as flake inputs:
- **capscreen**: Screen capture utility
- **dictator**: Voice dictation tool
- **diffgpt**: AI-powered diff analysis
- **dump**: Data dump utility
- **rollouts**: Deployment management

### Secrets Management
- **Encryption**: agenix for secret management
- **SSH Keys**: Machine-specific public keys for decryption
- **Environment Variables**: Encrypted API keys and configurations

## Development Workflow

1. **Make Changes**: Edit configuration files (NixOS system config or Home Manager user config)
2. **Test**: `nix flake check --no-build`
3. **Deploy**: `sudo nixos-rebuild switch --flake .#<machine>` (includes Home Manager)
4. **Rollback**: `sudo nixos-rebuild switch --rollback` (if needed)
5. **Home Manager only**: `home-manager switch --flake .#<user>@<machine>` (if needed)

## File Organization

### Core Files
- `flake.nix`: Defines inputs, outputs, and system configurations
- `configuration.nix`: System-wide settings (boot, networking, services)
- `common/user.nix`: User account configuration with Home Manager integration
- `dev/default.nix`: Development environment configuration (packages, programs, dotfiles)
- `desktop/default.nix`: Desktop environment configuration via Home Manager

### Machine-Specific
- `machines/<hostname>/default.nix`: Machine-specific configuration
- `machines/<hostname>/*.nix`: Hardware-specific modules

### Modules
- `common/`: Shared NixOS modules
- `dev/`: Development environment and user configuration (Home Manager)
- `desktop/`: Desktop environment setup via Home Manager (i3, apps managed declaratively)
- `secrets/`: Encrypted configuration files

## Adding New Machines

1. Create `machines/<hostname>/default.nix`
2. Add hardware configuration
3. Include machine-specific modules
4. Add to `flake.nix` nixosConfigurations
5. Update `secrets.nix` with new SSH key
6. Configure Home Manager integration in `common/user.nix`

## Updating Dependencies

```bash
# Update all inputs
nix flake update

# Update specific input
nix flake update <input-name>

# Check what will be updated
nix flake update --dry-run
```

## Troubleshooting

### Common Issues
- **Secrets not decrypting**: Check SSH key matches `secrets.nix`
- **Build failures**: Run `nix flake check` for syntax errors
- **Module not found**: Verify import paths in configuration files

### Debugging
```bash
# Show detailed evaluation trace
nix flake check --show-trace

# Build without switching
sudo nixos-rebuild build --flake .#<machine>

# Check system status
nixos-rebuild list-generations
```

## Security Notes

- Secrets are encrypted with agenix and machine-specific SSH keys
- No plaintext secrets in the repository
- SSH keys are managed per-machine for isolation
- Tailscale provides secure remote access
