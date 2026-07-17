import QtQuick
import "../"
import "../base"

// Rotating spinner icon for fullscreen overlays.
// One animated transform, not a Canvas repainting every frame per screen.
//
// Rotation freezes at its last angle when spinning goes false.
// Callers that show a settled state swap in a separate upright icon.

TintedIcon {
    id: root

    property bool spinning: visible
    property int spinDuration: 1000

    source: "../icons/icons8-spinner.svg"
    color: Colors.accentColor

    RotationAnimation on rotation {
        running: root.spinning
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: root.spinDuration
    }
}
