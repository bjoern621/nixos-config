import QtQuick

// Content replace transition: when `contentKey` changes,
// the content scales down + fades out, the `displayValue`
// updates at the midpoint, then scales back up + fades in.
//
// IMPORTANT: content must bind to `displayValue`, not directly
// to the source property, so the visual update is deferred.
//
// Usage:
//   ContentReplace {
//       id: replace
//       contentKey: someChangingValue
//       Text { text: replace.displayValue }
//   }
Item {
    id: root

    default property alias content: contentArea.data
    property var contentKey
    property var displayValue
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

        // Phase 1: scale down + fade out (old content)
        ParallelAnimation {
            NumberAnimation {
                target: contentArea
                property: "opacity"
                to: 0
                duration: root.duration
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: contentArea
                property: "scale"
                to: 0.5
                duration: root.duration
                easing.type: Easing.InCubic
            }
        }

        // Swap content at midpoint
        ScriptAction {
            script: root.displayValue = root.contentKey
        }

        // Phase 2: scale up + fade in (new content)
        ParallelAnimation {
            NumberAnimation {
                target: contentArea
                property: "opacity"
                to: 1
                duration: root.duration
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: contentArea
                property: "scale"
                to: 1.0
                duration: root.duration
                easing.type: Easing.OutCubic
            }
        }
    }

    property var _prevKey: undefined

    onContentKeyChanged: {
        if (_prevKey === undefined) {
            _prevKey = contentKey;
            displayValue = contentKey;
            return;
        }
        _prevKey = contentKey;

        replaceAnim.stop();
        contentArea.opacity = 1;
        contentArea.scale = 1.0;
        replaceAnim.start();
    }
}
