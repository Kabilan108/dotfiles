# NixOS Flake Configuration

A modular, flake-based NixOS configuration supporting multiple machines with shared and machine-specific settings.

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
nixos/
├── flake.nix                 # Main flake definition
├── flake.lock               # Pinned input versions
├── configuration.nix        # Shared system configuration
├── user.nix                 # User packages and environment
├── dev.nix                  # Development tools and languages
├── secrets.nix              # Agenix secrets configuration
├── machines/                # Machine-specific configurations
│   ├── sietch/
│   │   ├── default.nix      # Desktop system config
│   │   ├── nvidia.nix       # NVIDIA/CUDA setup
│   │   └── hardware-configuration.nix
│   └── jacurutu/
│       ├── default.nix      # Framework laptop config
│       ├── framework.nix    # Framework-specific settings
│       └── hardware-configuration.nix
├── modules/                 # Reusable NixOS modules
│   ├── agents.nix           # AI agent installations
│   ├── locale.nix           # Locale configuration
│   ├── systemd-dictator.nix # Dictator systemd service
│   └── xbox-controller.nix  # Gaming controller support
├── desktop/                 # Desktop environment
│   └── i3.nix              # i3 window manager setup
└── secrets/                 # Encrypted secrets (agenix)
    ├── env.json             # Environment variables
    └── authorized_keys      # SSH keys
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
- **i3 Window Manager**: Tiling window manager with custom keybindings
- **Development Environment**: Comprehensive LSP setup, languages, and tools
- **Audio**: PipeWire with PulseAudio compatibility
- **Networking**: NetworkManager with VPN support
- **Security**: Tailscale VPN, encrypted secrets via agenix

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

1. **Make Changes**: Edit configuration files
2. **Test**: `nix flake check --no-build`
3. **Deploy**: `sudo nixos-rebuild switch --flake .#<machine>`
4. **Rollback**: `sudo nixos-rebuild switch --rollback` (if needed)

## File Organization

### Core Files
- `flake.nix`: Defines inputs, outputs, and system configurations
- `configuration.nix`: System-wide settings (boot, networking, services)
- `user.nix`: User account, packages, and environment variables
- `dev.nix`: Development tools, languages, and Docker

### Machine-Specific
- `machines/<hostname>/default.nix`: Machine-specific configuration
- `machines/<hostname>/*.nix`: Hardware-specific modules

### Modules
- `modules/`: Reusable configuration modules
- `desktop/`: Desktop environment setup
- `secrets/`: Encrypted configuration files

## Adding New Machines

1. Create `machines/<hostname>/default.nix`
2. Add hardware configuration
3. Include machine-specific modules
4. Add to `flake.nix` nixosConfigurations
5. Update `secrets.nix` with new SSH key

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