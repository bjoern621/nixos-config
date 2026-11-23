import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import "../"

// TooltipBubble on a fullscreen layer surface of its own (Overlay layer,
// default `quickshell` namespace), for hosts too small to hold the bubble,
// such as the bar.
// Hyprland's blur layerrule applies behind it.
// A launcher overlay must place TooltipBubble in its own surface instead.
// TooltipBubble explains why.
//
// Caller supplies `anchorItem` (the item the tooltip points at) and `text`
// (and optionally `subtitle`).
// The tooltip centers itself on `anchorItem`, above it by default.
// Set `placement` to "below" for anchors at the top of the screen,
// such as items in the bar.
//
//   Tooltip {
//       anchorItem: hoveredItem
//       text: hoveredText
//       screen: hostWindow.screen
//       placement: "below"
//   }
//
// Set `anchorWindow` when the anchor lives in a surface smaller than the screen.
// `anchorDx` explains the offset.
Scope {
    id: root

    property alias text: bubble.text
    property alias subtitle: bubble.subtitle
    property alias textFormat: bubble.textFormat
    property alias maxContentWidth: bubble.maxContentWidth
    property alias anchorItem: bubble.anchorItem
    property alias verticalSpacing: bubble.verticalSpacing
    property alias recalcKey: bubble.recalcKey
    property alias placement: bubble.placement
    property var screen: null

    // Surface holding anchorItem, when it is not this window's size.
    // mapToItem(null, …) is window-relative, so an anchor in a smaller surface
    // reports coordinates this fullscreen window reads as top-left.
    // Both surfaces are centered on the same screen, so half the size
    // difference is the offset between them. Layer surfaces carry no position,
    // hence the derivation rather than reading x/y.
    // Null for anchors in a fullscreen host: the offset is then zero anyway.
    property var anchorWindow: null
    readonly property real anchorDx: anchorWindow ? (tooltipWindow.width - anchorWindow.width) / 2 : 0
    readonly property real anchorDy: anchorWindow ? (tooltipWindow.height - anchorWindow.height) / 2 : 0

    Connections {
        target: bubble
        function onShouldShowChanged() {
            if (bubble.shouldShow)
                tooltipWindow.visible = true;
        }
    }

    PanelWindow {
        id: tooltipWindow
        visible: false
        screen: root.screen
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        exclusiveZone: 0
        color: "transparent"
        mask: Region {}

        TooltipBubble {
            id: bubble
            anchors.fill: parent
            anchorDx: root.anchorDx
            anchorDy: root.anchorDy
            onHidden: tooltipWindow.visible = false
        }
    }
}
