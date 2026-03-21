import Quickshell
import QtQuick

Item {
    id: menuRoot

    property var menuHandle: null
    property var panelWindow: null

    signal itemTriggered()

    readonly property bool hovered: rootHover.hovered
    property var activeSubmenu: null
    property real submenuY: 0

    implicitWidth: mainPanel.implicitWidth + (submenuPanel.visible ? Spacing.spacing4 + submenuPanel.implicitWidth : 0)
    implicitHeight: Math.max(mainPanel.implicitHeight, submenuPanel.visible ? submenuY + submenuPanel.implicitHeight : 0)

    HoverHandler {
        id: rootHover
    }

    Timer {
        id: submenuCloseTimer
        interval: 300
        onTriggered: {
            if (!submenuHover.hovered) {
                menuRoot.activeSubmenu = null
            }
        }
    }

    // Main menu panel
    Rectangle {
        id: mainPanel
        implicitWidth: 200
        implicitHeight: mainContent.implicitHeight + 2 * Spacing.spacing8
        height: implicitHeight
        radius: Spacing.spacing12
        color: Colors.pillBackground
        border.width: 1
        border.color: Colors.pillBorder

        QsMenuOpener {
            id: opener
            menu: menuRoot.menuHandle
        }

        Column {
            id: mainContent
            anchors.fill: parent
            anchors.margins: Spacing.spacing8

            Repeater {
                model: opener.children

                Item {
                    width: mainContent.width
                    height: modelData.isSeparator ? 9 : 30

                    required property var modelData

                    Rectangle {
                        visible: modelData.isSeparator
                        width: parent.width
                        height: 1
                        anchors.centerIn: parent
                        color: Colors.separatorColor
                    }

                    Rectangle {
                        id: mainItemBg
                        visible: !modelData.isSeparator
                        anchors.fill: parent
                        radius: Spacing.spacing4
                        color: mainItemMouse.containsMouse && modelData.enabled
                                 ? Colors.hoverItemHovered : "transparent"
                        border.color: mainItemMouse.containsMouse && modelData.enabled
                                 ? Colors.pillBorder : "transparent"

                        Text {
                            id: mainCheckMark
                            visible: modelData.buttonType !== 0
                            text: modelData.checkState === Qt.Checked
                                    ? (modelData.buttonType === 1 ? "\u2713" : "\u25CF")
                                    : " "
                            color: Colors.textColor
                            font.pixelSize: 11
                            width: visible ? 16 : 0
                            anchors.left: parent.left
                            anchors.leftMargin: Spacing.spacing8
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Image {
                            id: mainItemIcon
                            source: modelData.icon ?? ""
                            visible: (modelData.icon ?? "") !== ""
                            width: 16
                            height: 16
                            sourceSize: Qt.size(16, 16)
                            anchors.left: mainCheckMark.right
                            anchors.leftMargin: visible ? Spacing.spacing4 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            smooth: true
                            mipmap: true
                        }

                        Text {
                            text: modelData.text ?? ""
                            color: modelData.enabled
                                     ? Colors.textColor : Colors.textColorMuted
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            anchors.left: mainItemIcon.visible ? mainItemIcon.right : mainCheckMark.right
                            anchors.leftMargin: Spacing.spacing6
                            anchors.right: mainSubmenuArrow.left
                            anchors.rightMargin: Spacing.spacing4
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: mainSubmenuArrow
                            visible: modelData.hasChildren
                            text: "\u203A"
                            color: Colors.textColorMuted
                            font.pixelSize: 16
                            anchors.right: parent.right
                            anchors.rightMargin: Spacing.spacing8
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        MouseArea {
                            id: mainItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                            onContainsMouseChanged: {
                                if (containsMouse) {
                                    if (modelData.hasChildren) {
                                        submenuCloseTimer.stop()
                                        menuRoot.activeSubmenu = modelData
                                        menuRoot.submenuY = mainItemBg.mapToItem(menuRoot, 0, 0).y
                                    } else if (menuRoot.activeSubmenu !== null) {
                                        submenuCloseTimer.restart()
                                    }
                                } else if (modelData.hasChildren) {
                                    submenuCloseTimer.restart()
                                }
                            }

                            onClicked: {
                                if (!modelData.enabled) return
                                if (modelData.hasChildren) {
                                    menuRoot.activeSubmenu = modelData
                                    menuRoot.submenuY = mainItemBg.mapToItem(menuRoot, 0, 0).y
                                } else {
                                    if (modelData.sendTriggered) modelData.sendTriggered()
                                    else modelData.triggered()
                                    menuRoot.itemTriggered()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Submenu panel
    Rectangle {
        id: submenuPanel
        visible: menuRoot.activeSubmenu !== null
        x: mainPanel.width + Spacing.spacing4
        y: menuRoot.submenuY
        implicitWidth: 200
        implicitHeight: subContent.implicitHeight + 2 * Spacing.spacing8
        height: implicitHeight
        radius: Spacing.spacing12
        color: Colors.pillBackground
        border.width: 1
        border.color: Colors.pillBorder

        HoverHandler {
            id: submenuHover
            onHoveredChanged: {
                if (hovered) submenuCloseTimer.stop()
            }
        }

        QsMenuOpener {
            id: subOpener
            menu: menuRoot.activeSubmenu
        }

        Column {
            id: subContent
            anchors.fill: parent
            anchors.margins: Spacing.spacing8

            Repeater {
                model: subOpener.children

                Item {
                    width: subContent.width
                    height: modelData.isSeparator ? 9 : 30

                    required property var modelData

                    Rectangle {
                        visible: modelData.isSeparator
                        width: parent.width
                        height: 1
                        anchors.centerIn: parent
                        color: Colors.separatorColor
                    }

                    Rectangle {
                        id: subItemBg
                        visible: !modelData.isSeparator
                        anchors.fill: parent
                        radius: Spacing.spacing4
                        color: subItemMouse.containsMouse && modelData.enabled
                                 ? Colors.hoverItemHovered : "transparent"
                        border.color: subItemMouse.containsMouse && modelData.enabled
                                 ? Colors.pillBorder : "transparent"

                        Text {
                            id: subCheckMark
                            visible: modelData.buttonType !== 0
                            text: modelData.checkState === Qt.Checked
                                    ? (modelData.buttonType === 1 ? "\u2713" : "\u25CF")
                                    : " "
                            color: Colors.textColor
                            font.pixelSize: 11
                            width: visible ? 16 : 0
                            anchors.left: parent.left
                            anchors.leftMargin: Spacing.spacing8
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Image {
                            id: subItemIcon
                            source: modelData.icon ?? ""
                            visible: (modelData.icon ?? "") !== ""
                            width: 16
                            height: 16
                            sourceSize: Qt.size(16, 16)
                            anchors.left: subCheckMark.right
                            anchors.leftMargin: visible ? Spacing.spacing4 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            smooth: true
                            mipmap: true
                        }

                        Text {
                            text: modelData.text ?? ""
                            color: modelData.enabled
                                     ? Colors.textColor : Colors.textColorMuted
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            anchors.left: subItemIcon.visible ? subItemIcon.right : subCheckMark.right
                            anchors.leftMargin: Spacing.spacing6
                            anchors.right: subSubmenuArrow.left
                            anchors.rightMargin: Spacing.spacing4
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: subSubmenuArrow
                            visible: modelData.hasChildren
                            text: "\u203A"
                            color: Colors.textColorMuted
                            font.pixelSize: 16
                            anchors.right: parent.right
                            anchors.rightMargin: Spacing.spacing8
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        MouseArea {
                            id: subItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                            onClicked: {
                                if (!modelData.enabled) return
                                if (modelData.hasChildren) {
                                    const pos = subItemBg.mapToItem(null, subItemBg.width, 0)
                                    modelData.display(menuRoot.panelWindow, pos.x, pos.y)
                                } else {
                                    if (modelData.sendTriggered) modelData.sendTriggered()
                                    else modelData.triggered()
                                    menuRoot.itemTriggered()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
