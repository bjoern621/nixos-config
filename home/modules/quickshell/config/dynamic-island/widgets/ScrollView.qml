import QtQuick
import ".."

// Vertical scroll container: internal Flickable + auto-reserved gutter +
// ScrollHandle. Default children fill an internal Column, so
//   ScrollView { height: ...; Repeater { ... } }
// scrolls and reserves the gutter whenever content overflows. Rows never sit
// under the bar; the gutter appears only while scrollable.
//
// Column-backed: renders every child, fits menu lists of tens of rows.
// Large virtualized models (launcher, clipboard, emoji) use a ListView/GridView
// with a sibling ScrollHandle, reserving the same Spacing.scrollGutter by hand.
Item {
    id: root

    default property alias content: column.data
    property alias spacing: column.spacing
    // Rows per wheel notch; 0 keeps the Flickable's native wheel.
    property real wheelStride: 0

    readonly property alias flickable: flick
    readonly property bool scrollable: flick.contentHeight > flick.height + 1

    implicitHeight: column.implicitHeight

    Flickable {
        id: flick
        anchors.fill: parent
        // Reserve the scroll gutter only while scrollable.
        anchors.rightMargin: root.scrollable ? Spacing.scrollGutter : 0
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        StepWheel {
            target: flick
            rowStride: root.wheelStride
            enabled: root.wheelStride > 0
        }

        Column {
            id: column
            width: flick.width
        }
    }

    ScrollHandle {
        target: flick
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }
}
