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

**IMPORTANT**: The window/layer rule syntax changes frequently. Before writing or modifying any window rules or layer rules, **always fetch the latest syntax** from the wiki using `WebFetch` on https://wiki.hypr.land/Configuring/Window-Rules/. Do not rely on the examples below — they may be outdated.

- Key layer rule effects: `blur on`, `ignore_alpha <float>`, `blur_popups on`, `xray on`, `dim_around on`.
- Anonymous syntax: `layerrule = <effect>, match:namespace <regex>`
- Named syntax uses a block: `layerrule { name = …; <effect> = …; match:namespace = …; }`

## Quickshell (QML Shell UI)

Quickshell QML files live in `home/modules/quickshell/config/`. All components use shared singletons for consistent styling: `Colors.qml`, `Typography.qml`, `Spacing.qml`.

### Spacing

Use `Spacing.*` constants. Preferred values are **4**, **8**, and **12**. Other values (`2`, `6`, `16`, `24`, `40`) exist but should be used sparingly and with good reason.

### Colors

Always use `Colors.*` properties — never hardcode color values. Key tokens:

- `hoverItemHovered` / `hoverItemPressed` for interactive state backgrounds
- `pillBorder` for hover borders
- `textColor` / `textColorMuted` for primary/secondary text
- `accentColor` for progress fills, sliders, active indicators

### Typography

Always use `Typography.*` font size constants (`fontSize12`, `fontSize14`, `fontSize16`, etc.) — never use literal font size numbers. Default label style is `fontSize14` bold (set in `Label.qml`). Use `Font.Normal` weight explicitly for secondary/muted text.

### Hover Effects

Interactive items should change both **background** and **border** on hover. The standard pattern (see `HoverItem.qml`):

- Default: transparent background, transparent border
- Hovered: `Colors.hoverItemHovered` background, `Colors.pillBorder` border
- Pressed: `Colors.hoverItemPressed` background, `Colors.pillBorder` border
- Always set `cursorShape: Qt.PointingHandCursor` on interactive areas.

### Border Radius

- For pills and circles, prefer the **calculated** approach: `radius: height / 2` (not a hardcoded value).
- For rounded rectangles (menu items, panels), use spacing constants: `Spacing.spacing4` or `Spacing.spacing8`.
- When nesting rounded containers (inner + outer border), adjust the inner radius to account for the spacing/thickness between them so the corner curvature looks uniform (e.g. `outerRadius - borderWidth`).

### Animations

The primary animation pattern is **fade + slight position change** (slide), as used in the calendar year transition and OSD popups. Use this pattern everywhere a show/hide or content transition fits.

**Easing**: Use `Easing.OutCubic` for enter/show animations and `Easing.InCubic` for exit/hide animations.

**Duration ranges**:

- **80–120ms**: Micro-interactions (slider feedback, small state changes)
- **150–200ms**: Menu show/hide, hover menus
- **200–300ms**: Content transitions (slide-in after fade-out, OSD popups)

**Standard show/hide combo** (OSD example):

- Show: slide up ~16px + fade in, `OutCubic`, 180–220ms
- Hide: slide down ~16px + fade out, `InCubic`, 180–220ms

**Menu timing**: 250ms delay before showing, 200ms delay before hiding (prevents flicker on brief mouse passes).

### Component Patterns

- **Singletons** (`Colors`, `Typography`, `Spacing`) for all design tokens.
- **`HoverItem`** as the base for any interactive pill/button with hover state.
- **`HoverMenu`** as the animated wrapper for dropdown content.
- **`Scope`** wrapper for self-contained OSD/overlay features.
- **`Variants`** with `Quickshell.screens` model for per-screen windows.
