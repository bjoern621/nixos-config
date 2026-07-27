import QtQuick
import Quickshell.Hyprland
import "../"

// Outside-click and focus-loss dismissal, shared by the launcher overlays.
// Covers every close except Escape and picking an entry, which the host owns.
//
// Two paths, neither redundant:
// - Focus grab. Surfaces are card-sized, so a click on another window never
//   reaches the overlay. Hyprland clears the grab and swallows that click.
// - Focus loss. Another overlay mapping steals keyboard focus with no click,
//   which the grab does not report.
//
// Host must set WlrKeyboardFocus.OnDemand. Exclusive pins keyboard focus
// through clicks on other windows, so activeFocus never drops and neither path
// fires. OnDemand without the grab is no good either: focus-follows-mouse hands
// focus back to the window under the cursor and the overlay closes itself.
QtObject {
    id: root

    // Layer surface the grab covers.
    // Untyped: PanelWindow is not a declarable QML type here.
    required property var hostWindow
    // Focus holder inside hostWindow, watched for focus loss.
    required property Item watch
    // Tracks host visibility.
    property bool active: false

    signal dismissed

    property AutoCloseOnFocusLoss _focusLoss: AutoCloseOnFocusLoss {
        watch: root.watch
        armed: root.active
        onLost: root.dismissed()
    }

    property HyprlandFocusGrab _grab: HyprlandFocusGrab {
        windows: [root.hostWindow]
        active: root.active
        onCleared: root.dismissed()
    }
}
