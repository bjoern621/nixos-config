import QtQuick

// Swaps content when `contentKey` changes.
// Scales down + fades out, swaps `displayValue` at midpoint, scales up + fades in.
//
// Content must bind to `displayValue`, never the source property.
// Direct binding skips the deferred swap, so old content never shows during scale-down.
//
// Needs an explicit size.
// implicitWidth/implicitHeight track childrenRect, which loops when content
// anchors back to the container (centerIn, fill).
//
// Usage:
//   ContentReplace {
//       id: replace
//       contentKey: someChangingValue
//       width: 24; height: 24
//       Text { text: replace.displayValue }
//   }
Item {
    id: root

    default property alias content: contentArea.data
    property var contentKey
    // Seeded on first key, never bound.
    // A binding tracks contentKey live and defeats the first midpoint swap.
    property var displayValue
    // Total transition, split across fade-out and fade-in.
    property int duration: 150

    clip: true
    implicitWidth: contentArea.childrenRect.width
    implicitHeight: contentArea.childrenRect.height

    Item {
        id: contentArea
        width: root.width
        height: root.height
        transformOrigin: Item.Center
    }

    SequentialAnimation {
        id: replaceAnim

        ParallelAnimation {
            NumberAnimation {
                target: contentArea
                property: "opacity"
                to: 0
                duration: root.duration / 2
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: contentArea
                property: "scale"
                to: 0.5
                duration: root.duration / 2
                easing.type: Easing.InCubic
            }
        }

        // Swap lands at midpoint, between the two phases.
        ScriptAction {
            script: root.displayValue = root.contentKey
        }

        ParallelAnimation {
            NumberAnimation {
                target: contentArea
                property: "opacity"
                to: 1
                duration: root.duration / 2
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: contentArea
                property: "scale"
                to: 1.0
                duration: root.duration / 2
                easing.type: Easing.OutCubic
            }
        }
    }

    // Dedicated latch.
    // A contentKey passing through undefined would re-arm the seed path and
    // swallow the next transition.
    property bool _seeded: false

    // Re-arms the seed path, so the next contentKey lands without the swap.
    // For a consumer whose content arrives under a reveal of its own.
    function skipNextSwap() {
        root._seeded = false;
    }

    onContentKeyChanged: {
        replaceAnim.stop();
        contentArea.opacity = 1;
        contentArea.scale = 1.0;

        if (!_seeded) {
            _seeded = true;
            displayValue = contentKey;
            return;
        }

        replaceAnim.start();
    }
}
