import Quickshell
import QtQuick
import "../"

// One panel of a tray context menu: the entries of a single menu handle.
// Used for both the root menu and its submenus, since a QsMenuEntry is itself
// a valid handle.
//
// Binding a QsMenuOpener to a handle is what tells the application its menu is
// open (Quickshell refcounts the handle and sends the dbusmenu AboutToShow and
// "opened" events), so a submenu panel must only exist while it is on screen.
Rectangle {
    id: panel

    property var menuHandle: null

    // `y` is the entry's top edge in panel coordinates, for aligning a submenu.
    signal submenuRequested(var entry, real y)
    signal submenuLeft

    readonly property bool hovered: panelHover.hovered

    implicitWidth: 260
    implicitHeight: content.implicitHeight + 2 * Spacing.spacing8
    width: implicitWidth
    height: implicitHeight

    radius: Shape.cardRadius
    color: Colors.pillBackground
    border.width: Shape.usesBlur ? 1 : Shape.borderWidth
    border.color: Colors.pillBorder

    HoverHandler {
        id: panelHover
    }

    QsMenuOpener {
        id: opener
        menu: panel.menuHandle
    }

    // Quickshell already drops entries the application marked invisible, but it
    // passes separators through verbatim. Real menus lean on the toolkit to
    // tidy those up: nm-applet ends its menu with a separator and blueman emits
    // adjacent ones, both of which would draw stray lines.
    readonly property var entries: {
        const source = opener.children ? opener.children.values : [];
        const out = [];
        for (let i = 0; i < source.length; i++) {
            const entry = source[i];
            if (entry.isSeparator && (out.length === 0 || out[out.length - 1].isSeparator))
                continue;
            out.push(entry);
        }
        while (out.length > 0 && out[out.length - 1].isSeparator)
            out.pop();
        return out;
    }

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: Spacing.spacing8

        Repeater {
            model: panel.entries

            Item {
                id: row

                required property var modelData

                width: content.width
                // Labels are not always one line: Tailscale titles its account
                // entry "<account>\n<tailnet>".
                height: modelData.isSeparator ? 9 : Math.max(30, label.implicitHeight + Spacing.spacing8)

                readonly property bool interactive: !modelData.isSeparator && modelData.enabled

                Rectangle {
                    visible: row.modelData.isSeparator
                    width: parent.width
                    height: 1
                    anchors.centerIn: parent
                    color: Colors.separatorColor
                }

                Item {
                    id: itemBg
                    visible: !row.modelData.isSeparator
                    anchors.fill: parent

                    // Menu rows use the shared row background.
                    LauncherDelegateBg {
                        hovered: row.interactive && itemMouse.containsMouse
                    }

                    Text {
                        id: checkMark
                        visible: row.modelData.buttonType !== 0
                        text: {
                            if (row.modelData.checkState === Qt.Checked)
                                return row.modelData.buttonType === 1 ? "✓" : "●";
                            // dbusmenu toggle-state -1 ("indeterminate") arrives
                            // as PartiallyChecked.
                            if (row.modelData.checkState === Qt.PartiallyChecked)
                                return "−";
                            return "";
                        }
                        color: Colors.textColor
                        font.pixelSize: Typography.fontSize12
                        width: visible ? 16 : 0
                        anchors.left: parent.left
                        anchors.leftMargin: Spacing.spacing8
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // Menus mix both kinds: blueman's entries are all symbolic
                    // glyphs, while Tailscale's account entry carries the
                    // user's avatar. TrayIcon tints only the former.
                    TrayIcon {
                        id: itemIcon
                        source: row.modelData.icon ?? ""
                        visible: (row.modelData.icon ?? "") !== ""
                        size: 16
                        color: Colors.textColor
                        opacity: row.modelData.enabled ? 1 : 0.5
                        anchors.left: checkMark.right
                        anchors.leftMargin: visible ? Spacing.spacing4 : 0
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: label
                        text: row.modelData.text ?? ""
                        color: row.modelData.enabled ? Colors.textColor : Colors.textColorMuted
                        font.pixelSize: Typography.fontSize12
                        font.family: Typography.fontFamily
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        anchors.left: itemIcon.visible ? itemIcon.right : checkMark.right
                        anchors.leftMargin: Spacing.spacing6
                        anchors.right: submenuArrow.left
                        anchors.rightMargin: Spacing.spacing4
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: submenuArrow
                        visible: row.modelData.hasChildren
                        text: "›"
                        color: Colors.textColorMuted
                        font.pixelSize: Typography.fontSize16
                        anchors.right: parent.right
                        anchors.rightMargin: Spacing.spacing8
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !row.modelData.isSeparator
                        cursorShape: row.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onContainsMouseChanged: {
                            if (!containsMouse) {
                                if (row.modelData.hasChildren)
                                    panel.submenuLeft();
                                return;
                            }
                            if (row.modelData.hasChildren)
                                panel.submenuRequested(row.modelData, itemBg.mapToItem(panel, 0, 0).y);
                            else
                                panel.submenuLeft();
                        }

                        onClicked: {
                            if (!row.interactive)
                                return;
                            if (row.modelData.hasChildren) {
                                panel.submenuRequested(row.modelData, itemBg.mapToItem(panel, 0, 0).y);
                                return;
                            }
                            // Quickshell wires this signal to the dbusmenu
                            // "clicked" event for the entry.
                            row.modelData.triggered();
                        }
                    }
                }
            }
        }
    }
}
