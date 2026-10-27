import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import "../"

// Reusable tooltip bubble. Lives on its own Wayland layer surface (Overlay
// layer, default `quickshell` namespace) so Hyprland's blur layerrule applies
// behind it: the tooltip sees the layer below (e.g. the picker pill) blurred.
//
// Caller supplies `anchorItem` (the item the tooltip points at) and `text`
// (and optionally `subtitle`). The tooltip self-positions centered on
// `anchorItem`, above it by default. Set `placement` to "below" for anchors at
// the top of the screen, such as items in the bar. If the anchor moves due to
// scrolling or layout changes that don't alter its own properties (e.g. an
// outer ListView's contentY), bind `recalcKey` to that value to trigger
// position recomputation.
//
//   Tooltip {
//       anchorItem: hoveredCell
//       text: hoveredText
//       subtitle: hoveredSubtitle
//       screen: hostWindow.screen
//       anchorWindow: hostWindow
//       recalcKey: scrollView.contentY
//   }
//
// `anchorWindow` is only needed when the anchor lives in a surface smaller than
// the screen, such as the card-sized launcher overlays. See `anchorDx`.
Scope {
    id: root

    property string text: ""
    property string subtitle: ""
    property int textFormat: Text.PlainText
    property int maxContentWidth: 260
    property Item anchorItem: null
    property var screen: null
    property int verticalSpacing: Spacing.spacing4
    property var recalcKey: 0

    // Surface holding anchorItem, when it is not this window's size.
    // mapToItem(null, …) is window-relative, so an anchor in a card-sized
    // overlay reports coordinates this fullscreen window reads as top-left.
    // Both surfaces are centered on the same screen, so half the size
    // difference is the offset between them. Layer surfaces carry no position,
    // hence the derivation rather than reading x/y.
    // Null for anchors in a fullscreen host: the offset is then zero anyway.
    property var anchorWindow: null
    readonly property real anchorDx: anchorWindow ? (tooltipWindow.width - anchorWindow.width) / 2 : 0
    readonly property real anchorDy: anchorWindow ? (tooltipWindow.height - anchorWindow.height) / 2 : 0

    // "above" | "below", relative to anchorItem.
    property string placement: "above"
    readonly property bool placeBelow: placement === "below"

    readonly property bool shouldShow: text !== "" && anchorItem !== null

    onShouldShowChanged: {
        if (shouldShow)
            tooltipWindow.visible = true;
    }

    // Callers hide the bubble by clearing text or anchorItem.
    // Content and position hold their last shown values through the hide animation.
    // Live values would shrink the bubble empty and drop it to the top-left corner.
    // delayed: `when` and `value` both track text and anchorItem.
    // Only the settled pair tells a hide from a change.
    property string shownText: ""
    property string shownSubtitle: ""

    Binding {
        target: root
        property: "shownText"
        value: root.text
        when: root.shouldShow
        delayed: true
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: root
        property: "shownSubtitle"
        value: root.subtitle
        when: root.shouldShow
        delayed: true
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: reveal
        property: "x"
        value: root.anchoredX()
        when: root.shouldShow
        delayed: true
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: reveal
        property: "y"
        value: root.anchoredY()
        when: root.shouldShow
        delayed: true
        restoreMode: Binding.RestoreNone
    }

    function anchoredX() {
        if (!root.anchorItem)
            return 0;
        const _ = root.recalcKey;
        const p = root.anchorItem.mapToItem(null, root.anchorItem.width / 2, 0);
        const min = Spacing.spacing8;
        const max = tooltipWindow.width - reveal.width - Spacing.spacing8;
        return Math.max(min, Math.min(max, p.x + root.anchorDx - reveal.width / 2));
    }

    function anchoredY() {
        if (!root.anchorItem)
            return 0;
        const _ = root.recalcKey;
        if (root.placeBelow) {
            const b = root.anchorItem.mapToItem(null, 0, root.anchorItem.height);
            return b.y + root.anchorDy + root.verticalSpacing;
        }
        const p = root.anchorItem.mapToItem(null, 0, 0);
        return p.y + root.anchorDy - reveal.height - root.verticalSpacing;
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

        Connections {
            target: reveal
            function onHidden() {
                tooltipWindow.visible = false;
            }
        }

        PopReveal {
            id: reveal

            showing: root.shouldShow
            // Slide out of the anchor: down from its bottom, or up from its top.
            edge: root.placeBelow ? Qt.TopEdge : Qt.BottomEdge
            showDuration: 80
            hideDuration: 60

            implicitWidth: bubble.implicitWidth
            implicitHeight: bubble.implicitHeight
            width: implicitWidth
            height: implicitHeight

            Rectangle {
                id: bubble
                anchors.fill: parent
                implicitWidth: col.implicitWidth + Spacing.spacing12 * 2
                implicitHeight: col.implicitHeight + Spacing.spacing8 * 2
                radius: Spacing.spacing8
                color: Colors.pillBackground
                border.width: Shape.usesBlur ? 1 : Shape.thinBorderWidth
                border.color: Colors.pillBorder

                Column {
                    id: col
                    anchors.centerIn: parent
                    spacing: Spacing.spacing2
                    width: Math.min(
                        Math.max(titleLabel.implicitWidth, subLabel.implicitWidth),
                        root.maxContentWidth)

                    Label {
                        id: titleLabel
                        text: root.shownText
                        textFormat: root.textFormat
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Label {
                        id: subLabel
                        visible: root.shownSubtitle !== ""
                        text: root.shownSubtitle
                        textFormat: root.textFormat
                        font.weight: Font.Normal
                        font.pixelSize: Typography.fontSize12
                        color: Colors.textColorMuted
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
