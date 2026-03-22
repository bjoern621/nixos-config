import QtQuick

Item {
    id: root

    default property alias content: contentContainer.data
    property bool expanded: false

    width: parent ? parent.width : 0
    height: expanded ? contentContainer.childrenRect.height : 0
    clip: true

    Behavior on height {
        NumberAnimation {
            duration: 250
            easing.type: root.expanded ? Easing.OutBack : Easing.InCubic
        }
    }

    opacity: expanded ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: root.expanded ? 200 : 120
            easing.type: root.expanded ? Easing.OutCubic : Easing.InCubic
        }
    }

    Item {
        id: contentContainer
        width: parent.width
        height: childrenRect.height
    }
}
