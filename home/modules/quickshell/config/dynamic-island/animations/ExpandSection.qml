import QtQuick

Item {
    id: root

    default property alias content: contentContainer.data
    property bool expanded: false
    property bool horizontal: false
    property int duration: 180

    clip: true

    states: [
        State {
            name: "collapsed"
            when: !root.expanded
            PropertyChanges {
                root.opacity: 0
                root.width: root.horizontal ? 0 : (root.parent ? root.parent.width : 0)
                root.height: root.horizontal ? contentContainer.childrenRect.height : 0
            }
        },
        State {
            name: "expanded"
            when: root.expanded
            PropertyChanges {
                root.opacity: 1
                root.width: root.horizontal ? contentContainer.childrenRect.width : (root.parent ? root.parent.width : 0)
                root.height: contentContainer.childrenRect.height
            }
        }
    ]

    transitions: [
        Transition {
            from: "collapsed"
            to: "expanded"
            NumberAnimation {
                properties: root.horizontal ? "width,opacity" : "height,opacity"
                duration: root.duration
                easing.type: Easing.OutCubic
            }
        },
        Transition {
            from: "expanded"
            to: "collapsed"
            NumberAnimation {
                properties: root.horizontal ? "width,opacity" : "height,opacity"
                duration: root.duration
                easing.type: Easing.InCubic
            }
        }
    ]

    // Sized to content, not to root.
    // Root animates 0 -> content size and clips, so content holds natural size throughout.
    //
    // Content sizes itself.
    // Deriving height from this Item (anchors.fill, height: parent.height) feeds
    // childrenRect back into its own source and settles at 0.
    Item {
        id: contentContainer
        width: root.horizontal ? childrenRect.width : parent.width
        height: childrenRect.height
    }
}
