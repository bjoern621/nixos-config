import QtQuick
import "../"

// Static, standalone action button. Theme-adaptive, one look per theme:
//   Classic: rounded pill, transparent at rest, accent tint on hover/press, squish-scale press.
//   Neo: bordered cream block over a hard ink offset shadow; press slides the face onto the shadow.
// For static, large-enough targets only (power actions, apply/cancel, calendar year nav).
// List rows and small repeated cells stay on HoverItem/ButtonBg, never this.
// State colors come from ButtonBg, so the button never re-encodes the state -> color map.
Pressable {
    id: root

    property string iconSource: ""
    property alias label: txt.text
    property bool accent: false          // primary/highlighted variant (solid accent fill)
    property bool centered: false        // center icon+label instead of left-aligning
    property int iconSize: Typography.fontSize20
    property color iconColor: Colors.textColor
    property real iconRotation: 0
    property int fontPixelSize: Typography.fontSize12
    property real cornerRadius: neo ? NeoTokens.pillRadius : Spacing.spacing8

    readonly property bool neo: !Shape.usesBlur
    // Lighter than the containing card's shadow; 0 in classic.
    readonly property int shadowOffset: Shape.buttonShadowOffset
    readonly property real faceWidth: width - shadowOffset
    readonly property real faceHeight: height - shadowOffset

    // Content-sized by default; callers override width/height for fixed footprints.
    implicitWidth: row.implicitWidth + 2 * Spacing.spacing12 + shadowOffset
    implicitHeight: row.implicitHeight + 2 * Spacing.spacing8 + shadowOffset

    // Neo presses by sliding the face onto the shadow; classic squishes. Not both.
    pressedScale: neo ? 1.0 : 0.96

    // Face travel toward the shadow: 0 at rest, a nudge on hover, full on press.
    property real faceOffset: !neo || !enabled ? 0
        : pressed ? shadowOffset
        : hovered ? Math.round(shadowOffset * 0.4)
        : 0
    SquishBehavior on faceOffset { duration: 90 }

    // Hard ink offset shadow, neo only. Disabled buttons read flat, no shadow.
    Rectangle {
        visible: root.neo && root.enabled
        x: root.shadowOffset
        y: root.shadowOffset
        width: root.faceWidth
        height: root.faceHeight
        radius: NeoTokens.pillRadius
        color: NeoTokens.ink
    }

    ButtonBg {
        anchors.fill: undefined
        x: root.faceOffset
        y: root.faceOffset
        width: root.faceWidth
        height: root.faceHeight

        active: root.accent
        // A disabled button reads flat: no hover tint, no press.
        hovered: root.hovered && root.enabled
        pressed: root.pressed && root.enabled
        cornerRadius: root.cornerRadius
        restColor: root.neo ? NeoTokens.paper : "transparent"
        borderAlways: root.neo

        Row {
            id: row
            x: root.centered ? (parent.width - width) / 2 : Spacing.spacing12
            anchors.verticalCenter: parent.verticalCenter
            spacing: Spacing.spacing8

            TintedIcon {
                visible: root.iconSource !== ""
                source: root.iconSource
                size: root.iconSize
                color: root.iconColor
                rotation: root.iconRotation
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: txt
                visible: text !== ""
                anchors.verticalCenter: parent.verticalCenter
                color: Colors.textColor
                font.family: Typography.fontFamily
                font.pixelSize: root.fontPixelSize
                font.weight: Typography.weightBold
            }
        }
    }
}
