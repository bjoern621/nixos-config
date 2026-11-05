import QtQuick
import ".."

// Draggable scroll handle overlay. Drives target.contentY; geometry from
// target.visibleArea.
// Place as a sibling of the list, anchored right/top/bottom. Pair with StepWheel
// on the list for the wheel step.
Rectangle {
    id: track

    property Flickable target
    property real barWidth: 8
    property real minHandle: 24

    // Track
    property color trackColor: NeoTokens.hoverPaper
    property int trackBorderWidth: NeoTokens.thinBorderWidth
    property color trackBorderColor: NeoTokens.ink

    // Handle
    property color handleColor: NeoTokens.ink
    property color handlePressedColor: NeoTokens.accentColor

    readonly property real _handleH: target ? Math.max(minHandle, height * target.visibleArea.heightRatio) : 0
    readonly property real _travel: height - _handleH
    property real _dragY: 0
    property real _grabY: 0

    visible: target && target.contentHeight > target.height + 1
    width: barWidth
    radius: barWidth / 2
    color: trackColor
    border.width: trackBorderWidth
    border.color: trackBorderColor

    Rectangle {
        id: handle
        x: 0
        width: parent.width
        radius: parent.radius
        height: track._handleH
        // ListView with uneven rows re-estimates contentHeight and shifts originY as delegates load.
        // visibleArea then jumps, so handle follows cursor while dragged.
        y: dragArea.pressed ? track._dragY : track.target ? track._travel * track.target.visibleArea.yPosition / Math.max(0.0001, 1 - track.target.visibleArea.heightRatio) : 0
        color: dragArea.pressed ? track.handlePressedColor : track.handleColor

        MouseArea {
            id: dragArea
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => {
                track._dragY = handle.y;
                track._grabY = mapToItem(track, 0, mouse.y).y - handle.y;
            }
            onPositionChanged: mouse => {
                if (!pressed || track._travel <= 0 || !track.target)
                    return;
                const top = mapToItem(track, 0, mouse.y).y - track._grabY;
                track._dragY = Math.max(0, Math.min(track._travel, top));
                const frac = track._dragY / track._travel;
                const maxY = Math.max(0, track.target.contentHeight - track.target.height);
                track.target.contentY = track.target.originY + frac * maxY;
            }
        }
    }
}
