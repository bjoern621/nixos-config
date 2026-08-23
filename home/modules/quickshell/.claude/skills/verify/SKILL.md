---
name: verify
description: Drive the running Quickshell shell to observe a QML change end-to-end (reload, notifications, screenshots).
---

# Verifying Quickshell changes

`~/.config/quickshell` is an out-of-store symlink to
`home/modules/quickshell/config/dynamic-island` in this repo, so edits are live
without a rebuild. `sysconf-reload` is only needed for changes to
`quickshell.nix` itself (packages, wrapper deps, layer rules).

## Reload

The watcher compares content, not mtime.
`touch` and a byte-identical rewrite both do nothing.
A QML file whose bytes differ reloads the whole config immediately, leaf or entry file alike, so an ordinary edit needs no push.
Confirm it landed:

```bash
sleep 2
journalctl --user -u quickshell.service --since "-15s" --no-pager
```

The watcher covers QML only.
A `.js` source reaches the engine through a QML `import` and is not watched, so editing one reloads nothing on its own.
Follow it with an edit to a QML file, or restart.

Restarting is also how to force a reload with nothing to edit:

```bash
systemctl --user restart quickshell.service
```

A reload rebuilds every Scope, which clears transient state such as the toast
model. That is the fastest way to clear stuck overlays.

A write that replaces the file instead of writing into it (`sed -i`, an editor's atomic save) can leave the watch on the discarded inode, and that file's next edit then passes unnoticed.
The next reload from any source re-arms it, so editing a second file recovers the watch.

Errors surface only in the journal:

```bash
journalctl --user -u quickshell.service --since "-5min" --no-pager
```

A healthy reload logs `Reloading configuration...` then `Configuration Loaded`.
Anything in between is real: filtering the output hides the defect rather than the noise.
Some warnings fire on every load regardless of the change under test, so reload once more without editing to tell a pre-existing one from a new one.

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

The user's pointer is off limits.
No `hl.dsp.cursor.move`, no `wlrctl pointer`, no warping, nudging, or restoring, ever.
This is a live desktop: the pointer belongs to the user.

A part that only appears under the pointer (bar hover menus) is not driven synthetically.
Finish the change, confirm the reload is clean in the journal, and tell the user it is ready to check by hovering.

`/dev/uinput` is root-only, so ydotool does not work. `wtype` covers keyboard input only.

Stacked overlays shadow each other: a non-expiring toast keeps the top slot and
absorbs clicks meant for a newer one. Reload, or close it, before measuring.

## Gotchas found the hard way

`Notification.expireTimeout` is **milliseconds**, matching the D-Bus value,
even though the upstream docs say seconds.

`trackedNotifications` does not yet contain a notification while
`onNotification` runs, so anything reading it at delegate construction sees
nothing. Bindings that read `trackedNotifications.values` re-evaluate once it
lands.
