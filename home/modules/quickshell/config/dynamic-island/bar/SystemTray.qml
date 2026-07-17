import Quickshell.Services.SystemTray
import Quickshell.Hyprland
import QtQuick
import "../"

// Background apps exposed over the StatusNotifierItem protocol.
//
// Mouse handling follows the SNI spec's button mapping: left click activates
// the item, right click opens its menu, middle click is the secondary action
// and the wheel scrolls it. Items that set ItemIsMenu have no activation
// response, so for those the spec says to prefer the menu on left click too.
Item {
    id: trayRoot

    implicitWidth: trayRow.implicitWidth
    implicitHeight: trayRow.implicitHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    // Input properties from Bar
    property var panelWindow: null
    property Item menuParent: null
    property real menuTopY: 0

    // Uniform popup contract consumed by Bar.qml. The menu counts as open for
    // as long as it is on screen, including while it animates away, so the
    // bar's input mask keeps covering it.
    readonly property bool popupOpen: trayMenuContainer.visible
    readonly property alias popupItem: trayMenuContainer

    property bool expanded: false

    readonly property int iconCellSize: 26
    readonly property int attentionDotSize: 6

    // Tray icons keep their native colours, bar symbolic ones which TrayIcon
    // tints so they stay visible. An app whose icon ships an opaque or dark
    // background draws as a solid block against the translucent bar; to force
    // one either way, add its id here. `pattern` is a regular expression
    // because some apps put their pid in the id.
    //
    //   readonly property var iconModeOverrides: [
    //       { pattern: "^systray_\\d+$", mode: "tint" } // Tailscale
    //   ]
    readonly property string defaultIconMode: "auto"
    readonly property var iconModeOverrides: []

    function iconModeFor(itemId) {
        for (let i = 0; i < trayRoot.iconModeOverrides.length; i++) {
            const override = trayRoot.iconModeOverrides[i];
            if (new RegExp(override.pattern).test(itemId))
                return override.mode;
        }
        return trayRoot.defaultIconMode;
    }

    // Drives the menu-dismiss check only.
    // The Repeater binds SystemTray.items directly and hides Passive per delegate.
    // .filter() reads every item's status, so any status change yields a fresh array.
    // Assigning that to `model` rebuilds every delegate, reloading icons and
    // dropping hover.
    readonly property var trayItems: SystemTray.items.values.filter(item => item.status !== Status.Passive)

    QtObject {
        id: internal
        property bool menuOpen: false
        property var activeItem: null
        property real menuAnchorX: 0
        property var hoveredItem: null
        property Item hoveredIcon: null
        // Trails hoveredItem by `tooltipDelay`; see below.
        property var tooltipItem: null
    }

    // Sweeping along the row shouldn't flash a tooltip per icon, so a tooltip
    // waits the same 150ms the bar's other hover menus do. Clearing on every
    // change stops the previous icon's text lingering over the new one.
    Timer {
        id: tooltipDelay
        interval: 150
        onTriggered: internal.tooltipItem = internal.hoveredItem
    }

    Connections {
        target: internal
        function onHoveredItemChanged() {
            internal.tooltipItem = null;
            if (internal.hoveredItem)
                tooltipDelay.restart();
            else
                tooltipDelay.stop();
        }
    }

    function openMenuFor(item, anchorX) {
        if (!item || !item.hasMenu)
            return;
        // Clicking the item whose menu is already up closes it; clicking a
        // different item swaps the menu over rather than just dismissing.
        if (internal.menuOpen && internal.activeItem === item) {
            trayRoot.closeMenu();
            return;
        }
        internal.activeItem = item;
        internal.menuAnchorX = anchorX;
        internal.menuOpen = true;
    }

    function closeMenu() {
        internal.menuOpen = false;
    }

    onExpandedChanged: if (!expanded) trayRoot.closeMenu()

    // An entry that removes its own item from the tray, such as a Quit, would
    // otherwise leave the menu behind as an empty panel: the handle dies with
    // the item and the entries drain away, but nothing dismisses the menu.
    onTrayItemsChanged: if (internal.menuOpen && !trayRoot.trayItems.includes(internal.activeItem)) trayRoot.closeMenu()

    // Hyprland clears the grab when a click lands outside the bar, which is
    // what dismisses the menu without the click having to reach this window.
    HyprlandFocusGrab {
        id: menuGrab
        windows: trayRoot.panelWindow ? [trayRoot.panelWindow] : []
        active: internal.menuOpen
        onCleared: trayRoot.closeMenu()
    }

    // --- Main row: arrow + icons ---

    Row {
        id: trayRow
        spacing: Spacing.spacing4
        anchors.verticalCenter: parent.verticalCenter

        HoverItem {
            id: arrowButton
            implicitWidth: height
            onClicked: trayRoot.expanded = !trayRoot.expanded

            Item {
                anchors.centerIn: parent
                width: arrow.implicitWidth
                height: arrow.implicitHeight

                ExpandArrow {
                    id: arrow
                    anchors.centerIn: parent
                    expanded: trayRoot.expanded
                    iconSize: Typography.fontSize16
                    iconColor: Colors.textColor
                    collapsedRotation: 270
                    expandedRotation: 90
                }
            }
        }

        ExpandSection {
            id: iconsContainer
            horizontal: true
            expanded: trayRoot.expanded
            duration: 180
            anchors.verticalCenter: parent.verticalCenter

            Row {
                id: iconRow
                // Icons sit flush against each other; their hover pills provide
                // the separation.
                spacing: 0

                Repeater {
                    model: SystemTray.items

                    Item {
                        id: iconItem

                        required property var modelData

                        // Spec reserves Passive for items with nothing worth showing.
                        // Row skips invisible children, so hiding lays out the same
                        // as filtering the model.
                        visible: iconItem.modelData.status !== Status.Passive

                        width: trayRoot.iconCellSize
                        height: trayRoot.iconCellSize

                        readonly property bool menuShown: internal.menuOpen && internal.activeItem === iconItem.modelData
                        readonly property bool needsAttention: modelData.status === Status.NeedsAttention

                        function toggleMenu() {
                            trayRoot.openMenuFor(iconItem.modelData, iconItem.mapToItem(trayRoot, iconItem.width / 2, 0).x);
                        }

                        scale: iconMouse.pressed ? 0.85 : 1.0
                        SquishBehavior on scale {}

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: iconMouse.pressed || iconItem.menuShown ? Colors.hoverItemPressed : iconMouse.containsMouse ? Colors.hoverItemHovered : "transparent"
                            border.color: iconMouse.containsMouse || iconMouse.pressed || iconItem.menuShown ? Colors.pillBorder : "transparent"
                            // NO Behavior on color; hover must be instant
                        }

                        TrayIcon {
                            anchors.centerIn: parent
                            source: iconItem.modelData.icon
                            size: Typography.fontSize16
                            mode: trayRoot.iconModeFor(iconItem.modelData.id)
                        }

                        // NeedsAttention is the spec's "the user should look at
                        // this" state, e.g. a chat mention.
                        Rectangle {
                            visible: iconItem.needsAttention
                            width: trayRoot.attentionDotSize
                            height: trayRoot.attentionDotSize
                            radius: height / 2
                            color: Colors.accentColor
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 1
                        }

                        MouseArea {
                            id: iconMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                            onEntered: {
                                internal.hoveredItem = iconItem.modelData;
                                internal.hoveredIcon = iconItem;
                            }

                            onExited: {
                                if (internal.hoveredIcon === iconItem) {
                                    internal.hoveredItem = null;
                                    internal.hoveredIcon = null;
                                }
                            }

                            onClicked: function (mouse) {
                                if (mouse.button === Qt.LeftButton) {
                                    if (iconItem.modelData.onlyMenu) {
                                        iconItem.toggleMenu();
                                    } else {
                                        trayRoot.closeMenu();
                                        iconItem.modelData.activate();
                                    }
                                } else if (mouse.button === Qt.RightButton) {
                                    iconItem.toggleMenu();
                                } else if (mouse.button === Qt.MiddleButton) {
                                    trayRoot.closeMenu();
                                    iconItem.modelData.secondaryActivate();
                                }
                            }

                            onWheel: function (wheel) {
                                if (wheel.angleDelta.y !== 0)
                                    iconItem.modelData.scroll(wheel.angleDelta.y, false);
                                if (wheel.angleDelta.x !== 0)
                                    iconItem.modelData.scroll(wheel.angleDelta.x, true);
                            }
                        }
                    }
                }
            }
        }
    }

    // Lives on its own layer surface, so it is not clipped by the collapsing
    // icon container the way an in-bar bubble would be.
    Tooltip {
        placement: "below"
        verticalSpacing: Spacing.spacing8
        anchorItem: internal.hoveredIcon
        screen: trayRoot.panelWindow ? trayRoot.panelWindow.screen : null
        text: {
            if (internal.menuOpen || !internal.tooltipItem)
                return "";
            const item = internal.tooltipItem;
            return item.tooltipTitle || item.title || item.id;
        }
        subtitle: internal.tooltipItem ? internal.tooltipItem.tooltipDescription : ""
    }

    // --- Menu popup (reparented to menuParent) ---

    PopReveal {
        id: trayMenuContainer
        parent: trayRoot.menuParent ?? trayRoot
        showing: internal.menuOpen

        // The root panel is centred under its icon. Centring is deliberately on
        // `rootWidth` rather than the popup's full width: a submenu opens to the
        // right and widens the popup, which would otherwise shove the root panel
        // left every time one appeared. Clamping still uses the full width, so a
        // menu near the screen edge slides inwards far enough for its submenu.
        x: {
            const host = trayRoot.menuParent;
            if (!host)
                return 0;
            const centre = trayRoot.mapToItem(host, internal.menuAnchorX, 0).x;
            let px = centre - trayMenuContent.rootWidth / 2;

            const win = trayRoot.panelWindow;
            const fullWidth = trayMenuContainer.width;
            if (win && fullWidth > 0) {
                const margin = Spacing.spacing8;
                const left = host.mapFromItem(null, margin, 0).x;
                const right = host.mapFromItem(null, win.width - margin, 0).x - fullWidth;
                px = right < left ? left : Math.max(left, Math.min(px, right));
            }
            return px;
        }
        y: trayRoot.menuTopY
        width: trayMenuContent.implicitWidth
        height: trayMenuContent.implicitHeight

        onHidden: {
            internal.activeItem = null;
            trayMenuContent.activeSubmenu = null;
        }

        // Triggering an entry deliberately leaves the menu up. Only a click off
        // the menu dismisses it, so a toggle such as "Turn Bluetooth On" can be
        // flipped and its result read without the menu going away first. An
        // entry that opens a window still takes the focus grab with it, which
        // dismisses the menu on its own.
        TrayContextMenu {
            id: trayMenuContent
            anchors.fill: parent
            menuHandle: internal.activeItem ? internal.activeItem.menu : null
        }
    }
}
