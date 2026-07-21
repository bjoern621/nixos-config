---
name: verify
description: Drive the running Quickshell shell to observe a QML change end-to-end (reload, notifications, screenshots, synthetic clicks).
---

# Verifying Quickshell changes

`~/.config/quickshell` is an out-of-store symlink to
`home/modules/quickshell/config/dynamic-island` in this repo, so edits are live
without a rebuild. `sysconf-reload` is only needed for changes to
`quickshell.nix` itself (packages, wrapper deps, layer rules).

## Reload

Hot reload does not fire for every edit. Force it:

```bash
touch home/modules/quickshell/config/dynamic-island/shell.qml
sleep 3
journalctl --user -u quickshell.service --since "-10s" --no-pager | grep -E "Reloading|Loaded"
```

A reload rebuilds every Scope, which clears transient state such as the toast
model. That is the fastest way to clear stuck overlays.

Errors surface only in the journal:

```bash
journalctl --user -u quickshell.service --since "-5min" --no-pager
```

A healthy reload logs `Reloading configuration...` then `Configuration Loaded` and nothing else.
Anything in between is real: filtering the output hides the defect rather than the noise.

The IDE's QML language server cannot resolve Quickshell types and reports
`Rectangle was not found`, `Instantiator was not found` and similar for every
file. That output is noise; the journal is the only real check.

## Geometry

Screenshots need physical pixels, and monitors differ in scale. Always read the
current layout instead of assuming:

```bash
hyprctl monitors -j | python3 -c "
import sys, json
for m in json.load(sys.stdin):
    print(m['name'], f\"{m['width']}x{m['height']}\", 'scale=', m['scale'], 'pos=', (m['x'], m['y']))
"
```

Layer surfaces are worth checking directly, both to find a window and to confirm
the unmap-when-empty rule from CLAUDE.md:

```bash
hyprctl layers | grep quickshell
```

Windows built with `Variants` over `Quickshell.screens` (NotificationCenter, Bar)
exist per monitor. A bare `PanelWindow` with no `screen:` (NotificationToast)
appears on one monitor only, which is not always the internal panel.

## Screenshots

`grim` is in the user profile. `imagemagick` is a private dep of the quickshell
wrapper, so it is not on `PATH`; address it by store path:

```bash
IM=$(ls -d /nix/store/*imagemagick*/bin | head -1)
grim -o DP-7 - | $IM/magick png:- -crop 400x220+2160+0 +repage -resize 200% shot.png
```

To summon a specific UI part and crop tight to its layer surface, see the
`screenshot-ui` skill; it drives the show, locate, capture, move loop.

## Driving notifications

`notify-send` is private to the quickshell wrapper and not on `PATH`. Use gdbus:

```bash
gdbus call --session --dest org.freedesktop.Notifications \
  --object-path /org/freedesktop/Notifications \
  --method org.freedesktop.Notifications.Notify \
  "TestApp" 0 "" "Summary" "Body" \
  '["default","Open","reply","Antworten"]' '{"desktop-entry": <"org.kde.kwrite">}' 5000
```

The last argument is the expire timeout in milliseconds: `0` never expires and
`-1` leaves it to the shell. gdbus parses a bare `-1` as an option, so pass it as
`-- -1`.

Watch what the shell reports back to clients. This is the real evidence for
click and action wiring:

```bash
gdbus monitor --session --dest org.freedesktop.Notifications
```

A body click on a notification carrying a `default` action emits
`ActionInvoked(id, 'default')` then `NotificationClosed(id, 2)`. Reason 2 means
dismissed by the user. An action button emits its own key instead, and the close
button emits only `NotificationClosed`.

Check advertised server capabilities with:

```bash
gdbus call --session --dest org.freedesktop.Notifications \
  --object-path /org/freedesktop/Notifications \
  --method org.freedesktop.Notifications.GetCapabilities
```

Clients only send actions to a server that advertises `actions`.

## Synthetic input

`/dev/uinput` is root-only, so ydotool does not work. `wtype` is keyboard-only.
For pointer clicks:

```bash
hyprctl dispatch movecursor <x> <y>      # global layout coords, logical px
nix run nixpkgs#wlrctl -- pointer click left
```

Warping the cursor onto a surface it already sits on produces no motion event,
so no Wayland enter and no `HoverHandler.hovered`. Move away first, then onto the
target, then nudge a pixel. Restore the pointer afterwards with
`hyprctl cursorpos`, since this runs on a live desktop.

Stacked overlays shadow each other: a non-expiring toast keeps the top slot and
absorbs clicks meant for a newer one. Reload, or close it, before measuring.

## Gotchas found the hard way

`Notification.expireTimeout` is **milliseconds**, matching the D-Bus value,
even though the upstream docs say seconds.

`trackedNotifications` does not yet contain a notification while
`onNotification` runs, so anything reading it at delegate construction sees
nothing. Bindings that read `trackedNotifications.values` re-evaluate once it
lands.
