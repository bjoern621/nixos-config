import QtQuick
import "../"

// A tray item's context menu: the root panel plus, when an entry with children
// is hovered, a submenu panel beside it.
//
// Live menus nest exactly one level (Tailscale's exit nodes, nm-applet's
// available networks), which is all the dbusmenu spec's `children-display`
// vocabulary encourages, so two panels cover it.
Item {
    id: menuRoot

    property var menuHandle: null

    readonly property bool hovered: mainPanel.hovered || (submenuPanel.visible && submenuPanel.hovered)

    // Width of the root panel alone. A submenu widens `implicitWidth`, so anyone
    // centring this menu on a trigger must use this instead, or opening a
    // submenu would drag the root panel sideways.
    readonly property real rootWidth: mainPanel.implicitWidth

    property var activeSubmenu: null
    property real submenuY: 0

    implicitWidth: mainPanel.implicitWidth + (submenuPanel.visible ? Spacing.spacing4 + submenuPanel.implicitWidth : 0)
    implicitHeight: Math.max(mainPanel.implicitHeight, submenuPanel.visible ? menuRoot.submenuY + submenuPanel.implicitHeight : 0)

    function closeSubmenu() {
        menuRoot.activeSubmenu = null;
    }

    // Hovering off an entry and onto its submenu briefly crosses the gap
    // between the panels, so closing is deferred.
    Timer {
        id: submenuCloseTimer
        interval: 300
        onTriggered: {
            if (!submenuPanel.hovered)
                menuRoot.closeSubmenu();
        }
    }

    TrayMenuPanel {
        id: mainPanel
        menuHandle: menuRoot.menuHandle

        onSubmenuRequested: function (entry, y) {
            submenuCloseTimer.stop();
            menuRoot.activeSubmenu = entry;
            menuRoot.submenuY = y;
        }
        onSubmenuLeft: submenuCloseTimer.restart()
    }

    TrayMenuPanel {
        id: submenuPanel
        visible: menuRoot.activeSubmenu !== null
        x: mainPanel.width + Spacing.spacing4
        y: menuRoot.submenuY

        // Binding the handle only while visible is what signals "this submenu
        // is open" to the application.
        menuHandle: menuRoot.activeSubmenu

        onHoveredChanged: {
            if (hovered)
                submenuCloseTimer.stop();
            else
                submenuCloseTimer.restart();
        }
    }
}
