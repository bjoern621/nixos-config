import QtQuick
import Quickshell.Hyprland
import "../"

// Outside-click and focus-loss dismissal, shared by launcher overlays.
// Covers every close except Escape and picking an entry, which host owns.
//
// Two paths, neither redundant.
// Focus grab: surfaces are card-sized, click on another window never reaches overlay.
// Hyprland clears grab and swallows that click.
// Focus loss: keyboard focus leaving with no click, which grab does not report.
//
// Host must set WlrKeyboardFocus.OnDemand.
// Exclusive pins keyboard focus through clicks on other windows: activeFocus never drops, neither path fires.
// OnDemand without grab breaks too.
// Focus-follows-mouse hands focus back to window under cursor, overlay closes itself.
QtObject {
    id: root

    // Layer surface the grab covers.
    // Untyped: PanelWindow is not a declarable QML type here.
    required property var hostWindow
    // Focus holder inside hostWindow, watched for focus loss.
    required property Item watch
    // Tracks host visibility.
    property bool active: false

    // Another overlay opened after this one.
    // Host must unmap at once while superseded: `visible: <mapped> && !dismiss.superseded`.
    // Surface unmapping after its hide animation triggers Hyprland's unmap refocus,
    // which hands keyboard focus to window under pointer and closes newer overlay.
    // Unmapping before newer overlay maps lets that overlay take focus on map.
    readonly property bool superseded: Globals.activeLauncherOverlay !== null && Globals.activeLauncherOverlay !== root

    signal dismissed

    // Latches once host holds keyboard focus, resets on close.
    property bool _focused: false

    onActiveChanged: {
        if (active)
            Globals.activeLauncherOverlay = root;
        else
            _focused = false;
    }

    property Connections _focusLatch: Connections {
        target: root.watch
        function onActiveFocusChanged() {
            if (root.watch.activeFocus && root.active)
                root._focused = true;
        }
    }

    onSupersededChanged: {
        if (superseded && active)
            dismissed();
    }

    property AutoCloseOnFocusLoss _focusLoss: AutoCloseOnFocusLoss {
        watch: root.watch
        armed: root.active
        onLost: root.dismissed()
    }

    // Grab waits for focus on map.
    // Grab active before map sets seat focus directly, so Hyprland's focus state keeps previous window.
    // Any other layer unmapping (volume OSD, toast) then restores that window's focus past the grab.
    property HyprlandFocusGrab _grab: HyprlandFocusGrab {
        windows: [root.hostWindow]
        active: root.active && root._focused
        onCleared: root.dismissed()
    }
}
