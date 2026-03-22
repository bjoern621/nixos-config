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

All animations should feel **playful, squishy, and smooth**. The overall approach: hover feedback is instant, press/click feedback is squishy (scale down), and show/hide transitions use a coordinated fade + slide + scale pop.

**Easing reference**:

| Easing | Use for |
| --- | --- |
| `Easing.OutCubic` | Enter/show animations, general motion |
| `Easing.InCubic` | Exit/hide animations |
| `Easing.OutBack` | Scale "pop" on show (overshoots slightly for a bouncy feel) |
| `Easing.OutQuad` / `InQuad` | Continuous oscillating motion (e.g. music visualizer bars) |

**Duration ranges**:

| Range | Use for |
| --- | --- |
| **80–120ms** | Micro-interactions: slider feedback, squishy press, small state changes |
| **150–200ms** | Menu show/hide, panel transitions |
| **200–300ms** | Content transitions (slide-in after fade-out, OSD popups), album art bounce |
| **250–450ms** | Continuous looping animations (e.g. music visualizer bars) |

#### Hover: always instant

Hover state changes (background color, border) must be **instant** — no `Behavior on color`, no `ColorAnimation`. The color binding updates immediately via the ternary pattern:

```qml
color: pressed ? Colors.hoverItemPressed
     : hovered ? Colors.hoverItemHovered
     : "transparent"
// NO Behavior on color — hover must be instant
```

#### Press/click: squishy scale-down

Every clickable element should scale down on press for a tactile "squishy" feel. Use `Behavior on scale` with short duration:

```qml
scale: tapHandler.pressed ? 0.85 : 1.0
Behavior on scale {
    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
}
```

**Scale values by element size** (smaller elements scale more):

| Element | Pressed scale | Duration | Easing |
| --- | --- | --- | --- |
| Small icon buttons (32px) | `0.85` | 100ms | `OutCubic` |
| Medium buttons (40px), play/pause | `0.82` | 120ms | `OutBack` |
| Large interactive items (list rows, toggles) | `0.96`–`0.97` | 100ms | `OutCubic` |

Use `OutBack` for the primary action (play/pause) to give it extra bounciness. Use `OutCubic` for everything else.

#### Show/hide: fade + slide + scale pop

The standard pattern for popup/menu transitions (see `HoverMenu.qml`, `VolumeOsd.qml`, `SystemTray.qml`):

- **Show**: slide up ~8–16px + fade in (`OutCubic`, 150–220ms) + scale 0.96→1.0 (`OutBack`, 200–220ms)
- **Hide**: slide down ~8–16px + fade out (`InCubic`, 120–180ms) + scale 1.0→0.96 (`InCubic`, 120–180ms)
- Set `transformOrigin: Item.Top` so scaling anchors to the bar/trigger
- Initial state: `opacity: 0`, `scale: 0.96`

**When NOT to use scale pop**: Content transitions *within* an already-visible container (e.g. calendar year switching, expanding a section) should use fade + slide only, not scale. Scale pop is for showing/hiding the container itself.

#### Expandable sections: height + opacity

For collapsible content (e.g. Wiedergabeliste):

```qml
height: expanded ? contentColumn.implicitHeight : 0
clip: true
Behavior on height {
    NumberAnimation { duration: 250; easing.type: expanded ? Easing.OutBack : Easing.InCubic }
}
opacity: expanded ? 1 : 0
Behavior on opacity {
    NumberAnimation { duration: expanded ? 200 : 120; easing.type: expanded ? Easing.OutCubic : Easing.InCubic }
}
```

Use `OutBack` on expand for a bouncy overshoot, `InCubic` on collapse for a quick tuck-away.

#### Image/content loading: fade in

Images loaded asynchronously should fade in on ready:

```qml
opacity: status === Image.Ready ? 1 : 0
Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
```

#### Progress bars and sliders

Slider fill width and handle position animate at **80ms** with `OutCubic`, but only when NOT being dragged (disable animation during press):

```qml
Behavior on width {
    enabled: !sliderArea.pressed
    NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
}
```

OSD progress bars (volume, brightness) use **120ms** for a slightly smoother visual.

#### Menu timing

- **250ms** delay before showing a hover menu (prevents accidental triggers)
- **200ms** delay before hiding (prevents flicker on brief mouse passes)

### Component Patterns

- **Singletons** (`Colors`, `Typography`, `Spacing`) for all design tokens.
- **`HoverItem`** as the base for any interactive pill/button with hover state.
- **`HoverMenu`** as the animated wrapper for dropdown content.
- **`Scope`** wrapper for self-contained OSD/overlay features.
- **`Variants`** with `Quickshell.screens` model for per-screen windows.
