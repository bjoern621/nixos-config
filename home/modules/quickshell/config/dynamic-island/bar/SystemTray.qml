import Quickshell.Services.SystemTray
import QtQuick
import "../"

Item {
    id: trayRoot

    implicitWidth: iconRow.implicitWidth
    implicitHeight: iconRow.implicitHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    // Input properties from Bar
    property var panelWindow: null
    property Item menuParent: null
    property real menuTopY: 0

    // Exposed state for Bar (interactionZone sizing / shouldShowPill)
    readonly property bool menuVisible: internal.menuVisible
    readonly property real menuContentWidth: trayMenuContent.implicitWidth
    readonly property real menuContentHeight: trayMenuContent.implicitHeight

    QtObject {
        id: internal
        property bool menuOpen: false
        property var activeMenuHandle: null
        property real menuAnchorX: 0
        property bool menuVisible: false
    }

    function openMenu(menuHandle, iconCenterX) {
        internal.activeMenuHandle = menuHandle
        internal.menuAnchorX = iconCenterX
        internal.menuOpen = true
    }

    function closeMenu() {
        internal.menuOpen = false
    }

    // --- Icons ---

    Row {
        id: iconRow
        spacing: Spacing.spacing2
        anchors.verticalCenter: parent.verticalCenter

        HoverHandler {
            id: iconRowHover
        }

        Repeater {
            model: SystemTray.items

            Item {
                id: iconItem
                width: 26
                height: 26
                anchors.verticalCenter: parent.verticalCenter

                required property var modelData

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: iconMouse.pressed
                             ? Colors.hoverItemPressed
                             : iconMouse.containsMouse ? Colors.hoverItemHovered
                             : "transparent"
                    border.color: iconMouse.pressed || iconMouse.containsMouse
                             ? Colors.pillBorder : "transparent"
                }

                Image {
                    source: iconItem.modelData.icon
                    sourceSize: Qt.size(16, 16)
                    width: 16
                    height: 16
                    anchors.centerIn: parent
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }

                MouseArea {
                    id: iconMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: function(mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            if (iconItem.modelData.onlyMenu) {
                                iconItem.openContextMenu()
                            } else {
                                iconItem.modelData.activate()
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            iconItem.openContextMenu()
                        } else if (mouse.button === Qt.MiddleButton) {
                            iconItem.modelData.secondaryActivate()
                        }
                    }

                    onWheel: function(wheel) {
                        if (wheel.angleDelta.y !== 0)
                            iconItem.modelData.scroll(wheel.angleDelta.y, false)
                        else if (wheel.angleDelta.x !== 0)
                            iconItem.modelData.scroll(wheel.angleDelta.x, true)
                    }
                }

                function openContextMenu() {
                    if (!iconItem.modelData.hasMenu) return
                    if (internal.menuOpen) {
                        trayRoot.closeMenu()
                        return
                    }
                    const handle = iconItem.modelData.menu ?? null
                    if (!handle) return
                    trayRoot.openMenu(handle, iconItem.x + iconItem.width / 2)
                }

                // Tooltip
                property bool wantTooltip: iconMouse.containsMouse && iconItem.modelData.tooltipTitle !== "" && !internal.menuOpen
                property bool tooltipVisible: false

                onWantTooltipChanged: {
                    if (wantTooltip) {
                        tooltipShowTimer.restart()
                        tooltipHideTimer.stop()
                    } else {
                        tooltipShowTimer.stop()
                        tooltipHideTimer.restart()
                    }
                }

                Timer {
                    id: tooltipShowTimer
                    interval: 150
                    onTriggered: iconItem.tooltipVisible = true
                }

                Timer {
                    id: tooltipHideTimer
                    interval: 100
                    onTriggered: iconItem.tooltipVisible = false
                }

                Rectangle {
                    id: tooltipRect
                    visible: iconItem.tooltipVisible
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: Spacing.spacing4
                    width: tooltipText.implicitWidth + Spacing.spacing16
                    height: tooltipText.implicitHeight + Spacing.spacing8
                    radius: height / 2
                    color: Colors.pillBackground
                    border.width: 1
                    border.color: Colors.pillBorder
                    z: 100

                    Text {
                        id: tooltipText
                        anchors.centerIn: parent
                        text: iconItem.modelData.tooltipTitle
                        color: Colors.textColor
                        font.pixelSize: Typography.fontSize12
                    }
                }
            }
        }
    }

    // --- Menu popup (reparented to menuParent) ---

    PopReveal {
        id: trayMenuContainer
        parent: trayRoot.menuParent ?? trayRoot
        x: trayRoot.menuParent ? trayRoot.mapToItem(trayRoot.menuParent, internal.menuAnchorX, 0).x - 100 : 0
        y: trayRoot.menuTopY
        width: trayMenuContent.implicitWidth
        height: trayMenuContent.implicitHeight

        onShown: internal.menuVisible = true
        onHidden: {
            internal.menuVisible = false
            internal.activeMenuHandle = null
            trayMenuContent.activeSubmenu = null
        }

        TrayContextMenu {
            id: trayMenuContent
            anchors.fill: parent
            menuHandle: internal.activeMenuHandle
            panelWindow: trayRoot.panelWindow
            onItemTriggered: trayRoot.closeMenu()
        }
    }

    // --- Menu open/close logic ---

    readonly property bool anyHovered: trayMenuContent.hovered || iconRowHover.hovered

    onAnyHoveredChanged: {
        if (internal.menuOpen) {
            if (anyHovered) {
                closeTimer.stop()
            } else {
                closeTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 300
        onTriggered: {
            if (internal.menuOpen && !trayRoot.anyHovered) {
                trayRoot.closeMenu()
            }
        }
    }

    Connections {
        target: internal
        function onMenuOpenChanged() {
            if (internal.menuOpen) {
                closeTimer.stop()
                trayMenuContainer.show()
                // Start close timer immediately — if the user never hovers the menu,
                // the timer will fire and close it. If they do hover, it gets canceled.
                closeTimer.restart()
            } else {
                closeTimer.stop()
                trayMenuContainer.hide()
            }
        }
    }
}
