import QtQuick
import "../"

// Tooltip bubble drawn inside the caller's own surface.
// Fill the host window with it: anchoredX() and anchoredY() read window
// coordinates and clamp the bubble to this item.
//
// A launcher overlay must use this one.
// A separate tooltip surface unmapping after the pointer left the overlay
// makes Hyprland refocus the window under the cursor.
// That refocus ends the overlay's focus grab.
// LauncherDismiss then closes the overlay.
// Tooltip wraps this bubble in a fullscreen surface of its own, for hosts too
// small to hold it, such as the bar.
//
//   TooltipBubble {
//       anchors.fill: parent
//       anchorItem: hoveredCell
//       text: hoveredText
//       recalcKey: scrollView.contentY
//   }
//
// If the anchor moves due to scrolling or layout changes that don't alter its
// own properties (e.g. an outer ListView's contentY), bind `recalcKey` to that
// value to trigger position recomputation.
Item {
    id: root

    property string text: ""
    property string subtitle: ""
    property int textFormat: Text.PlainText
    property int maxContentWidth: 260
    property Item anchorItem: null
    property int verticalSpacing: Spacing.spacing4
    property var recalcKey: 0

    // Offset of the anchor's window inside this item.
    // Zero when both share one window.
    property real anchorDx: 0
    property real anchorDy: 0

    // "above" | "below", relative to anchorItem.
    property string placement: "above"
    readonly property bool placeBelow: placement === "below"

    readonly property bool shouldShow: text !== "" && anchorItem !== null

    // Emitted once the hide animation ends.
    signal hidden

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
        const max = root.width - reveal.width - Spacing.spacing8;
        return Math.max(min, Math.min(max, p.x + root.anchorDx - reveal.width / 2));
    }

    // Clamped as well, since a card-sized host clips a bubble above a row
    // scrolled half out of view.
    function anchoredY() {
        if (!root.anchorItem)
            return 0;
        const _ = root.recalcKey;
        let y;
        if (root.placeBelow) {
            const b = root.anchorItem.mapToItem(null, 0, root.anchorItem.height);
            y = b.y + root.anchorDy + root.verticalSpacing;
        } else {
            const p = root.anchorItem.mapToItem(null, 0, 0);
            y = p.y + root.anchorDy - reveal.height - root.verticalSpacing;
        }
        const min = Spacing.spacing8;
        const max = root.height - reveal.height - Spacing.spacing8;
        return Math.max(min, Math.min(max, y));
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

        onHidden: root.hidden()

        Rectangle {
            id: bubble
            anchors.fill: parent
            implicitWidth: col.implicitWidth + Spacing.spacing12 * 2
            implicitHeight: col.implicitHeight + Spacing.spacing8 * 2
            radius: Spacing.spacing8
            color: Colors.pillBackground
            border.width: Shape.thinBorderWidth
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
