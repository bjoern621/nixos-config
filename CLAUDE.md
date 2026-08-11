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
| `sysconf-reload`    | `sudo nixos-rebuild switch`                     | Copies hardware config and rebuilds the system. `--remote` builds here and activates over ssh on another host |
| `sysconf-update`    | `nix flake update && sudo nixos-rebuild switch` | Updates all flake inputs then rebuilds                      |
| `sysconf-pull`      | `git pull && sudo nixos-rebuild switch`         | Pulls latest config from remote then rebuilds               |
| `sysconf-help`      | (none)                                          | Shows help for all sysconf commands                         |
| `sysconf-audio-fix` | (none)                                          | Reloads TAS2781 speaker driver (workaround for suspend bug) |
| `sysconf-fix-monitors` | (none)                                       | Re-applies Hyprland monitor config (workaround for the mixed-scale cursor wall + layer-shell offset) |

## Secrets

Secrets live in `secrets/` as sops-encrypted YAML, each paired with a committed `*.yaml.template`.

**Never add, rename, or remove a key by editing the encrypted file first.** The template is the schema; the encrypted file only stores values. A key that exists only in the ciphertext is invisible to review.

1. Add the key with a placeholder to `secrets/<name>.yaml.template`.
2. Declare a matching `sops.secrets` entry in the consuming module.
3. Set the value: `sops --set '["<key>"] "<value>"' secrets/<name>.yaml`.
4. Rebuild, then restart the consuming service.

Step 3 precedes the rebuild: a `sops.secrets` entry whose key is missing **fails activation**. `EnvironmentFile` is read only at unit start, so a changed value needs a restart, not just a rebuild.

Recreating an encrypted file from its template (`cp` + `sops -e -i`) **destroys every real value in it**. Create-from-scratch only.

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

## Comments

Comments in this repo are caveman-terse: maximum density, zero filler.

This **fulfills** the "Writing style for docs and code comments" section of the global `~/.claude/CLAUDE.md` rather than replacing it.
Every rule there points the same way: no filler, no rhetorical scaffolding, no hedging, one idea per sentence, cut everything that does not pull its weight.
Caveman is those rules carried to their limit, so the global section still applies in full and this section says how far to take it.

The single deviation: the global section asks for prose that reads like a human technical writer, which implies complete sentences.
Comments here drop articles and use fragments instead.
Nothing else in the global section is relaxed, and the "one sentence per line" rule holds here too.

- Drop articles (`the`, `a`, `an`) wherever meaning survives.
- Drop connective filler: `so this`, `which is`, `in order to`, `rather than trusting`, `the case where`.
- Fragments are correct. Pattern: `[thing] [action] [reason].`
- Identifiers, error codes, flags, and units stay exact and unabbreviated: `ENOTCONN`, `Type=simple`, `SIGTERM`, `root_domain`, `--vfs-cache-mode`.
- Never trade a fact for brevity. Cutting words is free. Cutting facts is not.
- A comment states the constraint the code cannot show. Density does not license dropping the "why".

```nix
# Bad:  rclone unmounts on SIGTERM, so this covers only the case where it exits without doing so.
# Good: rclone unmounts on SIGTERM.
#       Covers only exit without unmount.
```

Markdown docs in this repo follow the global prose style unchanged. Caveman applies to comments only.

## Hyprland Configuration (Lua)

Hyprland is configured in its Lua syntax (hyprlang is deprecated).
Each concern lives in a real `.lua` file next to its Nix module, wired via `wayland.windowManager.hyprland.extraLuaFiles."<name>".content = ./<file>.lua;`.
Home Manager generates `~/.config/hypr/hyprland.lua`, which `require`s the files in alphabetical order of their attr names.
Window rules are last-match-wins across all files, so order-sensitive rule files use a `rules.NN-` attr prefix; pick a number that places new rules relative to the existing ones.
Other attrs use the plain concern name.

The authoritative reference for window rules and layer rules is:
https://wiki.hypr.land/Configuring/Basics/Window-Rules/

**IMPORTANT**: The window/layer rule syntax changes frequently. Before writing or modifying any window rules or layer rules, **always fetch the latest syntax** from the wiki using `WebFetch`. Do not rely on the examples below; they may be outdated.

- Window rules: `hl.window_rule({ name = …, match = { class = …, float = true, … }, <effect> = … })`
- Layer rules: `hl.layer_rule({ match = { namespace = <regex> }, <effect> = … })`
- Layer rule effects: `no_anim`, `blur`, `blur_popups`, `ignore_alpha <float>`, `dim_around`, `xray`, `animation <style>`, `order <int>`, `above_lock`, `no_screen_share`.
- `match.namespace` is a full match, so `quickshell` does not match `quickshell-launcher`.
- Binds: `hl.bind("SUPER + Q", hl.dsp.exec_cmd("…"), { locked = true, … })`; options: `hl.config({ … })`.

## Quickshell (QML Shell UI)

Quickshell QML files live in `home/modules/quickshell/config/`. All components use shared singletons for consistent styling: `Colors.qml`, `Typography.qml`, `Spacing.qml`.

### Spacing

Use `Spacing.*` constants. Preferred values are **4**, **8**, and **12**. Other values (`2`, `6`, `16`, `24`, `40`) exist but should be used sparingly and with good reason.

### Colors

Always use `Colors.*` properties. Never hardcode color values. Key tokens:

- `hoverItemHovered` / `hoverItemPressed` for interactive state backgrounds
- `pillBorder` for hover borders
- `textColor` / `textColorMuted` for primary/secondary text
- `accentColor` for progress fills, sliders, active indicators

### Typography

Always use `Typography.*` font size constants (`fontSize12`, `fontSize14`, `fontSize16`, etc.). Never use literal font size numbers. Default label style is `fontSize14` bold (set in `Label.qml`). Use `Font.Normal` weight explicitly for secondary/muted text.

### Hover Effects

Interactive items should change both **background** and **border** on hover. The standard pattern (see `HoverItem.qml`):

- Default: transparent background, transparent border
- Hovered: `Colors.hoverItemHovered` background, `Colors.pillBorder` border
- Pressed: `Colors.hoverItemPressed` background, `Colors.pillBorder` border
- Clickable areas use `cursorShape: Qt.PointingHandCursor`; non-clickable ones keep `Qt.ArrowCursor`. `HoverItem` derives this from its `clickable` property.

### Border Radius

- For pills and circles, prefer the **calculated** approach: `radius: height / 2` (not a hardcoded value).
- For rounded rectangles (menu items, panels), use spacing constants: `Spacing.spacing4` or `Spacing.spacing8`.
- When nesting rounded containers (inner + outer border), adjust the inner radius to account for the spacing/thickness between them so the corner curvature looks uniform (e.g. `outerRadius - borderWidth`).

### Animations

All animations should feel **playful, squishy, and smooth**. The overall approach: hover feedback is instant, press/click feedback is squishy (scale down), and show/hide transitions use a coordinated fade + slide + scale pop.

**Always use reusable animation components** (e.g. `SquishBehavior`, `PopReveal`) instead of writing inline `Behavior on <prop> { NumberAnimation { ... } }` blocks. If a reusable component exists for a pattern, use it.

**Easing reference**:

| Easing                      | Use for                                                     |
| --------------------------- | ----------------------------------------------------------- |
| `Easing.OutCubic`           | Enter/show animations, general motion                       |
| `Easing.InCubic`            | Exit/hide animations                                        |
| `Easing.OutBack`            | Scale "pop" on show (overshoots slightly for a bouncy feel) |
| `Easing.OutQuad` / `InQuad` | Continuous oscillating motion (e.g. music visualizer bars)  |

**Duration ranges**:

| Range         | Use for                                                                               |
| ------------- | ------------------------------------------------------------------------------------- |
| **60–100ms**  | Micro-interactions: slider feedback, squishy press, menu show/hide, panel transitions |
| **100–200ms** | Content transitions (slide-in after fade-out, OSD popups), album art bounce           |
| **250–450ms** | Continuous looping animations (e.g. music visualizer bars)                            |

#### Hover: always instant

Hover state changes (background color, border) must be **instant**. No `Behavior on color`, no `ColorAnimation`. The color binding updates immediately via the ternary pattern:

```qml
color: pressed ? Colors.hoverItemPressed
     : hovered ? Colors.hoverItemHovered
     : "transparent"
// NO Behavior on color; hover must be instant
```

#### Press/click: squishy scale-down

Every clickable element should scale down on press for a tactile "squishy" feel. Use the **`SquishBehavior`** reusable component. Never write inline `Behavior on scale` with a raw `NumberAnimation`:

```qml
scale: tapHandler.pressed ? 0.85 : 1.0
SquishBehavior on scale {}
// For bouncy primary actions (play/pause):
SquishBehavior on scale { bouncy: true; duration: 120 }
```

`SquishBehavior` properties: `duration` (default 100ms), `bouncy` (default false; uses `OutBack` when true).

It is a plain `Behavior`, so it applies to any numeric property, not only `scale`. `ExpandArrow` uses it on `rotation`. The same rule holds there: reach for it instead of an inline `Behavior` with a raw `NumberAnimation`.

**Scale values by element size** (smaller elements scale more):

| Element                                      | Pressed scale | `bouncy` | `duration`      |
| -------------------------------------------- | ------------- | -------- | --------------- |
| Small icon buttons (32px)                    | `0.85`        | `false`  | 100ms (default) |
| Medium buttons (40px), play/pause            | `0.82`        | `true`   | 120ms           |
| Large interactive items (list rows, toggles) | `0.96`–`0.97` | `false`  | 100ms (default) |

#### Show/hide: fade + slide + scale pop

Popup/menu transitions use **`PopReveal`** (see `HoverMenu.qml`, `VolumeOsd.qml`). It combines slide + fade + scale pop; drive it with `showing`, or call `show()` / `hide()`:

```qml
PopReveal {
    id: reveal
    edge: Qt.TopEdge   // slide origin; combinable, e.g. Qt.TopEdge | Qt.RightEdge
    showing: someFlag
    onHidden: window.visible = false
}
```

`PopReveal` properties: `slideOffset` (default `Spacing.spacing8`), `showDuration` / `hideDuration` (default 80ms), `showing`, `edge` (default `Qt.TopEdge`). Signals: `shown`, `hidden`. It sets `transformOrigin` from `edge`, holds `opacity: 0` / `scale: 0.96` when hidden, and is `visible` only while `opacity > 0`. The scale runs `showDuration + 50` on `OutBack` so the pop trails the fade.

`showing` is the single source of truth: `show()` and `hide()` write it rather than starting the animations, so both entry points stay in sync and re-entry is a no-op (`hide()` on a hidden reveal emits no second `hidden`). Drive it by binding `showing` **or** by calling `show()` / `hide()`, never both, since an imperative call destroys a binding on `showing`.

**When NOT to use scale pop**: Content transitions _within_ an already-visible container (e.g. calendar year switching, expanding a section) should use fade + slide only, not scale. Scale pop is for showing/hiding the container itself.

#### Directional content swap: fade out → swap → slide in

For a directional swap inside a visible container (the calendar's year navigation), use **`ContentSlide`**. It is fade + slide with no scale pop, which is what "When NOT to use scale pop" calls for.

```qml
ContentSlide {
    id: gridSlide
    onReadyToSwap: direction => {
        // Swap the content here, at the fade-out midpoint.
        gridSlide.completeTransition();
    }
    Grid { /* content */ }
}
```

`ContentSlide` properties: `slideOffset` (default 40), `fadeOutDuration` (default 120ms), `slideInDuration` (default 200ms), `fadeInDuration` (default 200ms). `transition(direction)` starts it. It emits `readyToSwap(direction)` once the old content has faded out, and the handler swaps the content and calls `completeTransition()`.

The content only changes when `readyToSwap` fires, so a caller stepping through values must accumulate onto the in-flight target rather than the displayed one. Reading the displayed value during a transition drops steps under rapid input.

#### Content replace: scale down → swap → scale up

When a value changes and the displayed content should swap in-place (e.g. a volume icon changing between muted/low/high), use **`ContentReplace`**. It scales down + fades out the old content, swaps to the new value at the midpoint, then scales back up + fades in:

```qml
ContentReplace {
    id: iconReplace
    contentKey: someChangingValue  // triggers animation on change
    width: 24; height: 24          // size it explicitly
    Text { text: iconReplace.displayValue }  // bind to displayValue, NOT the source
}
```

`ContentReplace` properties: `duration` (default 150ms, the total split across fade-out and fade-in), `contentKey` (watched value that triggers the transition), `displayValue` (seeded from the first `contentKey`, then re-assigned at the animation midpoint so the swap lands mid-transition).

**Important**: content inside must bind to `displayValue`, not directly to the source property. Direct binding bypasses the deferred swap and the old content won't be visible during scale-down.

**Give it an explicit size.** `implicitWidth` / `implicitHeight` track `childrenRect`, which forms a binding loop when the content anchors back to the container (`centerIn`, `fill`).

`contentKey` must be a value that changes in discrete steps. Keying it on a continuously-changing number restarts the transition on every step, so the content stutters instead of swapping.

#### Expandable sections: height + opacity

For collapsible content (e.g. the Wiedergabeliste in `NowPlayingMenu.qml`), use **`ExpandSection`**. It animates height + opacity via states/transitions and clips its content:

```qml
ExpandSection {
    expanded: root.queueExpanded
    Column { /* content */ }
}
```

`ExpandSection` properties: `expanded`, `horizontal` (animates width instead of height; default false), `duration` (default 180ms). Expand uses `OutCubic`, collapse uses `InCubic`.

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

Both timers live in `HoverItem.qml`:

- **150ms** delay before showing a hover menu (prevents accidental triggers)
- **100ms** delay before hiding (prevents flicker on brief mouse passes)

### Component Patterns

- **Singletons** (`Colors`, `Typography`, `Spacing`) for all design tokens.
- **`HoverItem`** as the base for any interactive pill/button with hover state.
- **`HoverMenu`** as the animated wrapper for dropdown content.
- **`Scope`** wrapper for self-contained OSD/overlay features.
- **`Variants`** with `Quickshell.screens` model for per-screen windows.

### Layer Surface Management (Performance)

**Every mapped PanelWindow creates a Wayland layer surface that Hyprland must composite and blur each frame.** With `Variants` per screen this multiplies quickly. Minimizing mapped surfaces is critical for battery life.

**Rule: A PanelWindow must be unmapped (`visible: false`) whenever it has no visible content.** Only windows that need always-on hover detection (Bar, PowerCorner, NotificationCenter) stay mapped, and those keep their idle input region as small as possible.

Verify with: `hyprctl layers | grep quickshell`

**Patterns by window type:**

| Type                       | Pattern                                                                     | Example                                     |
| -------------------------- | --------------------------------------------------------------------------- | ------------------------------------------- |
| Toggled overlay (IPC/flag) | `visible: <flag>` bound to the owning Scope's property                      | AppLauncher, ClipboardHistory, EmojiPicker  |
| Transient OSD              | `visible: false` default, set `true` before `show()`, `false` on `onHidden` | VolumeOsd, BrightnessOsd                    |
| Notification-driven        | `visible: <model>.count > 0`                                                | NotificationToast                           |
| Hover-triggered            | Keep mapped, **shrink** `implicitHeight` when idle                          | Bar (1000px idle-collapses to `0`, which the surface clamps to a 1px trigger strip) |
| Hover-triggered, fixed size| Keep mapped, shrink the **`mask` region** when idle                         | PowerCorner, NotificationCenter             |

**When adding a new PanelWindow**, always implement one of these patterns. Never leave a PanelWindow permanently mapped with no visibility management.

**Resizing a mapped layer surface is not free.** Hyprland animates a layer's size and stretches the client buffer into the animating box, so a surface that resizes on hover visibly distorts for a few frames under load. Any namespace whose window resizes or toggles needs `no_anim = true` in its layer rule.

**Namespace split:** layer rules match on the layer namespace, and `match.namespace` is a full match, so each namespace needs its own rules. A window selects one via:

```qml
import Quickshell.Wayland._WlrLayerShell
// ...
PanelWindow {
    WlrLayershell.namespace: "quickshell-noblur"
}
```

| Namespace              | Windows                        | Rules live in            |
| ---------------------- | ------------------------------ | ------------------------ |
| `quickshell` (default) | Bar, PowerCorner, NotificationCenter/Toast, OSDs, ModalOverlay, LoadingOverlay, Tooltip | `quickshell/layerrules.lua` |
| `quickshell-noblur`    | ScreenCorners, WallpaperChooser | (none; opts out of blur) |
| `quickshell-launcher`  | AppLauncher                    | `hyprland/app-launcher.lua` |
| `quickshell-clipboard` | ClipboardHistory               | `hyprland/clipboard-history.lua` |
| `quickshell-emoji`     | EmojiPicker                    | `hyprland/emoji-picker.lua` |

`quickshell-noblur` exists for windows that are purely decorative or opaque and gain nothing from blur. Per the One Concern Per File convention, a window with its own namespace carries its layer rules in that app's module, not in the quickshell module.

### Launcher Overlays

The app launcher, clipboard history and emoji picker are one kind of thing: a centered, keyboard-driven overlay with a search field over a scrollable result view. They behave identically, and a change to one belongs in the shared piece so the other two get it. A behavioural difference between them is a bug unless the file says why.

The app launcher renders two design variants (`AppLauncher` classic, `AppLauncherNeo`). Both follow every rule below; only their chrome differs.

**Surface.** Card-sized, never fullscreen. The window sets no `anchors`, so the compositor centers it, and takes its size from the panel:

```qml
implicitWidth: panel.surfaceWidth
implicitHeight: panel.surfaceHeight
```

A fullscreen transparent layer costs roughly 30fps on the battery iGPU, which is bandwidth-bound and blends the whole layer every frame.

**Fixed height.** The surface holds the overlay's tallest layout, not its current one, so typing does not resize the layer. Consumers pass that bound as `LauncherPanel.contentMaxHeight`, derived from the same constants that cap the view (`maxVisibleRows * rowHeight`, `maxVisibleHeight`, `cellSize * gridRows`). The panel itself still hugs its content and stays centered in the surface; a short result set leaves transparent slack. A bound that is too small costs a resize, not a clipped panel.

**Closing.** Escape and picking an entry are the host's business. Everything else is `LauncherDismiss`:

```qml
LauncherDismiss {
    hostWindow: fooWindow
    watch: panel
    active: scope.open
    onDismissed: scope.open = false
}
```

It pairs a `HyprlandFocusGrab` with `AutoCloseOnFocusLoss` because neither covers both cases. A card-sized surface never receives a click meant to dismiss it, so the grab reports the outside click and Hyprland swallows it; the grab stays silent when another overlay steals keyboard focus with no click, which is what focus loss catches.

The host must set `WlrKeyboardFocus.OnDemand`. `Exclusive` pins keyboard focus through clicks on other windows, so `activeFocus` never drops and neither path fires. `OnDemand` without the grab is equally broken: focus-follows-mouse hands focus back to the window under the cursor and the overlay closes itself a moment after opening.

**Scrolling.** `LauncherListView` / `LauncherGridView` for the view, which carry selection and the wheel step, and a `ScrollHandle` placed as a sibling. The view reserves the gutter only while it overflows:

```qml
width: parent.width - (scrollable ? Spacing.scrollGutter : 0)
```

The handle is a sibling and not a child because a Flickable reparents its children into `contentItem`.

**Selection.** `LauncherSelection`, reached through the view's `keyboardSelect()`, `reset()` and `effectiveIndex`. Consumers never write `currentIndex` or `hoveredIndex` directly: last input wins, and the distinction between a keystroke claiming the selection and the cursor claiming it lives in one place. Use `reset()` rather than `keyboardSelect(0)` when the model is replaced wholesale, since it also drops the stale hover and re-arms the gate that stops a view mapping under a stationary cursor from claiming the selection.

The launcher additionally registers its view as `LauncherController.selectionView`, so the singleton reads `effectiveIndex` back and drives `keyboardSelect()` regardless of which design variant is loaded. Both variants register, and clear the registration on destruction only if it still points at them, since on a theme switch the replacement view may register first. The clipboard and emoji picker own their state in their own `Scope` and call the view directly.

**Tooltips.** An overlay anchoring a `Tooltip` passes `anchorWindow`, since `mapToItem(null, …)` is window-relative and the tooltip lives on its own fullscreen surface. Omitting it places the bubble as if the card sat at the top-left of the screen.
