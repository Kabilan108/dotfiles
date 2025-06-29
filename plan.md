# NixOS Configuration Refactoring Plan

## Current State
The NixOS configuration is currently monolithic with a single `configuration.nix` file containing:
- 270 lines of mixed concerns
- System packages, development tools, GUI applications all in one place
- Makes it difficult to maintain and convert to a flake later

## Refactoring Options

### Option 1: Categorical Split (Recommended)
Break the monolithic config into logical categories:

```
nixos/
├── configuration.nix (main imports + basic settings)
├── machine.nix (unchanged)
├── modules/
│   ├── core/
│   │   ├── boot.nix (boot loader, kernel settings)
│   │   ├── networking.nix (network, firewall, tailscale)
│   │   └── users.nix (user accounts, groups, keys)
│   ├── development/
│   │   ├── languages.nix (go, python, nodejs, etc.)
│   │   ├── editors.nix (neovim + LSPs)
│   │   └── tools.nix (git, fzf, ripgrep, etc.)
│   ├── desktop/
│   │   ├── applications.nix (GUI apps)
│   │   ├── audio.nix (pipewire, bluetooth)
│   │   └── virtualization.nix (docker, virtualbox)
│   └── services.nix (system services)
```

**Benefits:**
- Clear separation of concerns
- Easy to find and modify specific functionality
- Perfect for flake conversion
- Follows NixOS community patterns

### Option 2: Functional Split
Organize by function/purpose:

```
nixos/
├── configuration.nix (minimal imports only)
├── machine.nix (unchanged)
├── modules/
│   ├── system-core.nix (boot, nix settings, locale)
│   ├── network-security.nix (networking, firewall, ssh)
│   ├── user-environment.nix (users, shell, basic tools)
│   ├── development-stack.nix (all dev tools, languages, LSPs)
│   ├── desktop-environment.nix (GUI apps, themes, audio)
│   └── services-virtualization.nix (services, docker, vbox)
```

**Benefits:**
- Fewer files to manage
- Grouped by related functionality
- Still maintainable

### Option 3: Layer-Based Split
Separate by system layers:

```
nixos/
├── configuration.nix (imports + machine-specific logic)
├── machine.nix (unchanged)
├── modules/
│   ├── base-system.nix (core system, boot, users, nix)
│   ├── packages/
│   │   ├── cli-tools.nix (system utilities, dev tools)
│   │   ├── gui-applications.nix (desktop apps)
│   │   └── development.nix (languages, LSPs, compilers)
│   ├── services-hardware.nix (all services, audio, bluetooth)
│   └── network-environment.nix (networking, env vars, paths)
```

**Benefits:**
- Clear package organization
- Good for dependency management
- Easier to see what's installed

## Recommendation

**Option 1 (Categorical Split)** is recommended because:
- Most maintainable long-term
- Best preparation for flake conversion
- Clear mental model for where things belong
- The `development/` subdirectory perfectly addresses the need to separate dev programs and LSPs

## Implementation Priority

1. **development/** modules first (languages.nix, editors.nix, tools.nix)
2. **core/** modules (boot.nix, networking.nix, users.nix)
3. **desktop/** modules (applications.nix, audio.nix, virtualization.nix)
4. Final cleanup and services.nix

## Flake Preparation Benefits

This structure will make flake conversion straightforward:
- Each module becomes a flake input/output
- Development environment can be easily shared
- Machine-specific configs remain isolated
- Modular imports work seamlessly with flakes