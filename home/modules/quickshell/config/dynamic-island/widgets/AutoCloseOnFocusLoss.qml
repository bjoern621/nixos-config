import QtQuick

// Emits `lost()` when keyboard focus leaves `watch` after having been there.
// Used by launcher windows to auto-close when another launcher opens or the
// user clicks any other surface. TapHandlers don't steal keyboard focus, so
// clicking subitems inside `watch` is safe.
//
// `armed` should track the window's visible flag. When it goes false the
// internal "had focus" latch resets so the next open re-arms cleanly.
QtObject {
    id: root
    required property Item watch
    property bool armed: true
    signal lost

    property bool _hadFocus: false
    onArmedChanged: if (!armed) _hadFocus = false

    property Connections _conn: Connections {
        target: root.watch
        function onActiveFocusChanged() {
            if (root.watch.activeFocus) root._hadFocus = true;
            else if (root._hadFocus && root.armed) root.lost();
        }
    }
}
