---
name: screenshot-ui
description: Summon a specific Quickshell UI part (overlay, menu, OSD, toast) and screenshot it to inspect how a QML change looks. Covers toggling parts into view via IPC/hover/gdbus, finding their layer geometry, cropping with grim, and moving a part that is clipped or off-screen. Use when the goal is to see a widget, not to verify its behavior.
---

# Screenshotting a Quickshell UI part

Use this to see how a UI part looks after a QML edit.
The `verify` skill covers whether a change behaves correctly (reload, notifications, input wiring).
This one covers capturing what a part looks like on screen.

Edits are live: `~/.config/quickshell` is an out-of-store symlink to the repo config, so a reload is enough, no rebuild.
Force the reload before capturing (see `verify`, Reload).

The loop is show the part, locate its surface, screenshot it.
A part that hides or overlaps needs a move first.

## Show the part

Transient windows are summoned over IPC.
The running shell registers:

| Command | Shows |
| --- | --- |
| `qs ipc call launcher toggle` | AppLauncher |
| `qs ipc call clipboard toggle` | ClipboardHistory |
| `qs ipc call emoji toggle` | EmojiPicker |
| `qs ipc call wallpaper toggle` | WallpaperChooser |
| `qs ipc call theme toggle` | ThemeSwitcher |
| `qs ipc call brightness show` | BrightnessOsd |
| `qs ipc call popup test` | ModalOverlay |

`qs ipc show` lists the live targets and methods; the table is whatever the running shell registered.
A `toggle` method also hides, so re-run it to dismiss.

Bar menus (calendar, network, bluetooth, now-playing, power) have no IPC handler.
They open on pointer hover over their Bar item, so summoning one means warping the cursor onto the item (see Move a part).

The notification toast and center are driven by real notifications; send one with gdbus (see `verify`, Driving notifications).

Always-mapped windows (Bar, PowerCorner, NotificationCenter) are on screen already, collapsed to a trigger strip until hovered, so they need no summoning.

## Locate the part

Each window is a Wayland layer surface.
Read its geometry by namespace:

```bash
hyprctl layers -j | python3 -c "
import sys, json
ns = 'quickshell-clipboard'
for mon, v in json.load(sys.stdin).items():
    for level in v['levels'].values():
        for l in level:
            if l['namespace'] == ns:
                print(mon, l['x'], l['y'], l['w'], l['h'])
"
```

Geometry is logical (compositor) pixels in the global layout, the same space `hyprctl monitors` reports.

| Namespace | Windows |
| --- | --- |
| `quickshell` | Bar, PowerCorner, NotificationCenter, NotificationToast, OSDs, ModalOverlay, ThemeSwitcher, bar menus |
| `quickshell-launcher` | AppLauncher |
| `quickshell-clipboard` | ClipboardHistory |
| `quickshell-emoji` | EmojiPicker |
| `quickshell-noblur` | ScreenCorners, WallpaperChooser |

Several windows share the `quickshell` namespace, so a namespace match alone does not pick one out.
They are told apart by geometry and by which are mapped: a bar menu is a content-sized box that exists only while open, the Bar is a full-width strip one pixel tall until hovered.

Two surface shapes, and the crop differs between them:

A content-sized surface (bar menu, OSD, corner, toast) has geometry equal to the visible panel, so its `x y w h` crops exactly to the part.

A full-screen overlay (launcher, clipboard, emoji) has a surface the size of its whole monitor with the panel centered inside, so the geometry is the monitor, not the panel.

## Screenshot the part

`grim` takes a logical region and writes physical pixels, honoring monitor scale, so feed it the geometry directly:

```bash
ns=quickshell-clipboard
read X Y W H < <(hyprctl layers -j | python3 -c "
import sys, json
ns = '$ns'
for v in json.load(sys.stdin).values():
    for level in v['levels'].values():
        for l in level:
            if l['namespace'] == ns:
                print(l['x'], l['y'], l['w'], l['h'])
")
grim -g "$X,$Y ${W}x${H}" shot.png
```

`read` grabs the first match, which is enough for a single-monitor window.
A per-monitor `Variants` window (Bar) has one surface per screen, so narrow by monitor when the wrong one comes back.

For a content-sized surface that region is the panel, cropped tight.

For a full-screen overlay `${W}x${H}` is the whole monitor with the panel centered.
Either capture the monitor and read the panel from the center, or crop a centered box around it:

```bash
# X Y W H = the overlay's monitor-sized surface geometry from above
CW=520; CH=640
grim -g "$((X + (W-CW)/2)),$((Y + (H-CH)/2)) ${CW}x${CH}" shot.png
```

Pick `CW`/`CH` to bracket the panel.
The launcher-family panel is 500 logical px wide, so 520 leaves a thin margin.

`imagemagick` is a private dep of the quickshell wrapper, not on `PATH`; reach it by store path to zoom for pixel detail:

```bash
IM=$(ls -d /nix/store/*imagemagick*/bin | head -1)
$IM/magick shot.png -resize 200% shot@2x.png
```

Write shots into the session scratchpad and read them back to inspect.

## Move a part

Layer surfaces are positioned by their own anchors, not by the compositor, so `hyprctl dispatch movewindow` does not touch them.
Two situations need a move.

**Summon a hover menu.**
A bar menu opens only while the pointer sits over its Bar item.
Save the pointer, warp onto the item, nudge a pixel so a Wayland enter fires, screenshot, then restore:

```bash
read PX PY < <(hyprctl cursorpos | tr -d ',')
hyprctl dispatch movecursor <bar_item_x> <bar_item_y>
# nudge one pixel, capture, then restore:
hyprctl dispatch movecursor "$PX" "$PY"
```

Warping onto a surface the pointer already occupies emits no motion event, so no hover fires; move away first, then onto the target.
Pointer-click mechanics live in `verify`, Synthetic input.

**Relocate a clipped or overlapping part.**
A part pinned off-screen or stacked under another surface has no runtime move.
Change its anchor or margin in the QML (flip `anchors.centerIn` to a corner, or add a margin), reload, screenshot, then revert.
The config is a live symlink, so revert is undo plus a reload.
