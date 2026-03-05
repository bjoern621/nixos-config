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

## Module Conventions

Follow the rules in [CONTRIBUTING.md](../CONTRIBUTING.md).

## Nix Style

- Prefer attribute set arguments over positional arguments in module functions.
- Use `mkEnableOption` / `mkOption` for module options.
- Keep modules self-contained; avoid cross-module dependencies unless necessary.

## Hyprland Rules

The authoritative reference for window rules and layer rules (props, effects, syntax) is:
https://wiki.hypr.land/Configuring/Window-Rules/

Key layer rule effects: `blur on`, `ignore_alpha <float>`, `blur_popups on`, `xray on`, `dim_around on`.
Anonymous syntax: `layerrule = <effect>, match:namespace <regex>`
Named syntax uses a block: `layerrule { name = …; <effect> = …; match:namespace = …; }`
