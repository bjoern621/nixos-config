import QtQuick
import "../"

// Static, standalone action button.
// Bordered cream block over hard ink offset shadow. Press slides face onto shadow.
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
    // progressMuted, a true grey.
    // textColorMuted sits a shade off ink, so that icon looks enabled.
    property color iconColor: enabled ? Colors.textColor : Colors.progressMuted
    property real iconRotation: 0
    property int fontPixelSize: Typography.fontSize12

    // Disabled face, border and icon fade together.
    readonly property real disabledOpacity: 0.6
    // Lighter than the containing card's shadow.
    readonly property int shadowOffset: Shape.buttonShadowOffset
    readonly property real faceWidth: width - shadowOffset
    readonly property real faceHeight: height - shadowOffset

    // Content-sized by default; callers override width/height for fixed footprints.
    implicitWidth: row.implicitWidth + 2 * Spacing.spacing12 + shadowOffset
    implicitHeight: row.implicitHeight + 2 * Spacing.spacing8 + shadowOffset

    // Press slides face onto shadow, so no squish on top.
    pressedScale: 1.0

    // Face travel toward the shadow: 0 at rest, a nudge on hover, full on press.
    property real faceOffset: !enabled ? 0
        : pressed ? shadowOffset
        : hovered ? Math.round(shadowOffset * 0.4)
        : 0
    SquishBehavior on faceOffset { duration: 90 }

    // Hard ink offset shadow. Disabled buttons read flat, no shadow.
    Rectangle {
        visible: root.enabled
        x: root.shadowOffset
        y: root.shadowOffset
        width: root.faceWidth
        height: root.faceHeight
        radius: Shape.pillRadius
        color: NeoTokens.ink
    }

    ButtonBg {
        anchors.fill: undefined
        x: root.faceOffset
        y: root.faceOffset
        width: root.faceWidth
        height: root.faceHeight

        // A disabled button reads flat and grey: no accent, no hover tint, no press,
        // grey fill under the outline, everything faded.
        active: root.accent && root.enabled
        hovered: root.hovered && root.enabled
        pressed: root.pressed && root.enabled
        opacity: root.enabled ? 1 : root.disabledOpacity
        restColor: root.enabled ? NeoTokens.paper : Colors.progressBackground
        borderAlways: true

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
                color: root.enabled ? Colors.textColor : Colors.progressMuted
                font.family: Typography.fontFamily
                font.pixelSize: root.fontPixelSize
                font.weight: Typography.weightBold
            }
        }
    }
}
