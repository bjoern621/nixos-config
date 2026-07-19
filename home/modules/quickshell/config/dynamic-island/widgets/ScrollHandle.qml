import QtQuick
import ".."

// Draggable scroll handle overlay. Drives target.contentY; geometry from
// target.visibleArea. Behavior identical across themes; visuals via style props.
// Place as a sibling of the list, anchored right/top/bottom. Pair with StepWheel
// on the list for the wheel step.
Rectangle {
    id: track

    property Flickable target
    // Theme-aware defaults: thin muted bar in classic, chunky cream/ink bar in neo.
    // A bare `ScrollHandle { target: list }` looks right in both themes.
    property real barWidth: Shape.usesBlur ? 4 : 8
    property real minHandle: 24

    // Track
    property color trackColor: Shape.usesBlur ? "transparent" : NeoTokens.hoverPaper
    property int trackBorderWidth: Shape.usesBlur ? 0 : NeoTokens.thinBorderWidth
    property color trackBorderColor: NeoTokens.ink

    // Handle
    property color handleColor: Shape.usesBlur ? Colors.textColorMuted : NeoTokens.ink
    property color handlePressedColor: Shape.usesBlur ? Colors.textColorMuted : NeoTokens.accentColor
    property real handleIdleOpacity: Shape.usesBlur ? 0.35 : 1.0
    property real handleActiveOpacity: Shape.usesBlur ? 0.6 : 1.0

    readonly property real _handleH: target ? Math.max(minHandle, height * target.visibleArea.heightRatio) : 0
    readonly property real _travel: height - _handleH

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
        y: track.target ? track._travel * track.target.visibleArea.yPosition / Math.max(0.0001, 1 - track.target.visibleArea.heightRatio) : 0
        color: dragArea.pressed ? track.handlePressedColor : track.handleColor
        opacity: (dragArea.pressed || (track.target && track.target.moving)) ? track.handleActiveOpacity : track.handleIdleOpacity

        MouseArea {
            id: dragArea
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            drag.target: parent
            drag.axis: Drag.YAxis
            drag.minimumY: 0
            drag.maximumY: track._travel
            onPositionChanged: {
                if (!pressed || track._travel <= 0 || !track.target)
                    return;
                const frac = handle.y / track._travel;
                const maxY = Math.max(0, track.target.contentHeight - track.target.height);
                track.target.contentY = frac * maxY;
            }
        }
    }
}
