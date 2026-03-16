# Project Overview

Personal NixOS daily driver configuration using `nixpkgs-unstable`. It combines NixOS system-level modules with Home Manager user-level modules in a single flake.

## Repository Structure

```
flake.nix          # Flake entry point, inputs, and nixosConfigurations
hosts/             # Host-specific configuration (hardware, per-machine settings)
modules/           # NixOS system modules (system-level config)
home/              # Home Manager entry point and user packages
home/modules/      # Home Manager modules (user-level config)
```

## Key Technologies

- **NixOS** with `nixpkgs-unstable`
- **Home Manager** for user-level configuration
- **Hyprland** as the Wayland compositor
- **Quickshell** for the desktop shell UI

## System Commands

Use the custom `sysconf-*` commands instead of raw NixOS commands:

| Command             | Use instead of                                  | What it does                                                |
| ------------------- | ----------------------------------------------- | ----------------------------------------------------------- |
| `sysconf-reload`    | `sudo nixos-rebuild switch`                     | Copies hardware config and rebuilds the system              |
| `sysconf-update`    | `nix flake update && sudo nixos-rebuild switch` | Updates all flake inputs then rebuilds                      |
| `sysconf-pull`      | `git pull && sudo nixos-rebuild switch`         | Pulls latest config from remote then rebuilds               |
| `sysconf-help`      | —                                               | Shows help for all sysconf commands                         |
| `sysconf-audio-fix` | —                                               | Reloads TAS2781 speaker driver (workaround for suspend bug) |

## Module Conventions

- **One Concern Per File**: each module contains configuration for a single application or feature.
- Configuration for an app (e.g. Hyprland layerrules for quickshell) belongs in that app's module, not in a shared rules file.
- When a concern spans both Home Manager and system-level config, add a comment explaining the split.
- Prefer attribute set arguments over positional arguments in module functions.
- Use `mkEnableOption` / `mkOption` for module options.
- Keep modules self-contained; avoid cross-module dependencies unless necessary.

## Nix Style

- Prefer attribute set arguments over positional arguments.
- Use `mkEnableOption` / `mkOption` for module options.
- Keep modules self-contained.

## Hyprland Rules

The authoritative reference for window rules and layer rules is:
https://wiki.hypr.land/Configuring/Window-Rules/

- Key layer rule effects: `blur on`, `ignore_alpha <float>`, `blur_popups on`, `xray on`, `dim_around on`.
- Anonymous syntax: `layerrule = <effect>, match:namespace <regex>`
- Named syntax uses a block: `layerrule { name = …; <effect> = …; match:namespace = …; }`
