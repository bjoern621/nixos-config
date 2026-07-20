import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import "../"
import "../base"
import "../lib/fzf.js" as FzfLib

// Self-contained neobrutalist app launcher.
// Opaque cream paper, 3px black borders, hard offset shadow. Selection + kbd
// pills take the wallpaper accent (Colors.accentColor), so the theme drives
// the one pop of color; everything else is fixed cream/black.
// No glass, no gradient, no blur: fully flat and loud. hyprglass sits behind the
// card but the opaque fill hides it entirely (harmless, drop it later if wanted).
// Shares no chrome/tokens with the other overlays. Only functional pieces are
// reused (DesktopEntries, fzf scoring, Globals visibility, focus-loss close).
Scope {
    id: launcherScope

    readonly property int rowHeight: 42
    readonly property int maxVisibleRows: 7

    // Neobrutalism palette. Opaque throughout, no alpha, no blur.
    // Selection + kbd pills pull the wallpaper accent (Colors.accentColor);
    // everything else is fixed cream/black.
    QtObject {
        id: theme
        readonly property string font: "Inter"
        readonly property color paper: "#fffdf5"
        readonly property color ink: "#111111"
        readonly property color selAccent: Colors.accentColor
        readonly property color selPressed: Qt.darker(Colors.accentColor, 1.12)
        readonly property color textPrimary: "#111111"
        readonly property color textMuted: "#3a382f"
        readonly property color placeholder: "#7a7768"
        // Hard offset shadow distance.
        readonly property int shadow: 7
    }

    PanelWindow {
        id: launcherWindow
        visible: LauncherController.launcherVisible
        WlrLayershell.namespace: "quickshell-launcher"
        screen: Quickshell.screens.find(s => s.name === Globals.launcherScreenName) ?? null

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        exclusiveZone: 0
        focusable: true
        WlrLayershell.keyboardFocus: LauncherController.launcherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        AutoCloseOnFocusLoss {
            watch: panelRoot
            armed: LauncherController.launcherVisible
            onLost: Globals.launcherVisible = false
        }

        Item {
            id: panelRoot
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                const k = event.key;
                const ctrl = event.modifiers & Qt.ControlModifier;
                let next = LauncherController.searchText;
                if (k === Qt.Key_Escape) {
                    Globals.launcherVisible = false;
                } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                    LauncherController.launchSelected();
                } else if (k === Qt.Key_Down) {
                    LauncherController.move(1);
                } else if (k === Qt.Key_Up) {
                    LauncherController.move(-1);
                } else if (k === Qt.Key_Backspace) {
                    next = ctrl ? LauncherController.searchText.replace(/\S+\s*$/, "") : LauncherController.searchText.slice(0, -1);
                } else if (k === Qt.Key_Delete || (k === Qt.Key_A && ctrl)) {
                    next = "";
                } else if (event.text && event.text.length > 0 && !ctrl) {
                    next = LauncherController.searchText + event.text;
                }
                if (next !== LauncherController.searchText)
                    LauncherController.searchText = next;
                event.accepted = true;
            }

            // Dismiss on click outside the card.
            MouseArea {
                anchors.fill: parent
                onClicked: Globals.launcherVisible = false
            }

            // Card + hard offset shadow group.
            Item {
                id: cardWrap
                width: 620 + theme.shadow
                height: card.height + theme.shadow
                anchors.centerIn: parent

                // Hard offset shadow: solid, no blur, down-right.
                Rectangle {
                    x: theme.shadow
                    y: theme.shadow
                    width: card.width
                    height: card.height
                    radius: 6
                    color: theme.ink
                }

                Rectangle {
                    id: card
                    x: 0
                    y: 0
                    width: 620
                    height: cardCol.implicitHeight
                    radius: 6
                    color: theme.paper
                    border.width: 3
                    border.color: theme.ink

                    // Click-eater: clicks inside the card must not dismiss.
                    MouseArea {
                        anchors.fill: parent
                    }

                    Column {
                        id: cardCol
                        width: parent.width

                        // Search header.
                        Item {
                            width: parent.width
                            height: 50

                            Item {
                                id: mag
                                width: 16
                                height: 16
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    id: magRing
                                    width: 11
                                    height: 11
                                    radius: 5.5
                                    color: "transparent"
                                    border.width: 2
                                    border.color: theme.ink
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                }
                                Rectangle {
                                    width: 5
                                    height: 2
                                    radius: 1
                                    color: theme.ink
                                    x: magRing.x + magRing.width - 1
                                    y: magRing.y + magRing.height - 1
                                    rotation: 45
                                    transformOrigin: Item.TopLeft
                                }
                            }

                            Item {
                                anchors.left: mag.right
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                height: 24

                                Text {
                                    visible: LauncherController.searchText === ""
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Anwendung oder Befehl suchen..."
                                    color: theme.placeholder
                                    font.family: theme.font
                                    font.pixelSize: 15
                                    font.weight: Font.ExtraBold
                                }

                                Row {
                                    visible: LauncherController.searchText !== ""
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: LauncherController.searchText
                                        color: theme.textPrimary
                                        font.family: theme.font
                                        font.pixelSize: 15
                                        font.weight: Font.ExtraBold
                                    }
                                    // Bold block cursor: solid, steady, no blink.
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 9
                                        height: 18
                                        color: theme.ink
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 3
                            color: theme.ink
                        }

                        // Results.
                        Item {
                            id: resultsRegion
                            width: parent.width
                            readonly property bool empty: LauncherController.filteredApps.length === 0 && LauncherController.searchText !== ""
                            implicitHeight: empty ? 120 : contentCol.implicitHeight + 16

                            // Empty state, centered in the results region.
                            Text {
                                visible: resultsRegion.empty
                                anchors.centerIn: parent
                                text: "Keine Ergebnisse"
                                color: theme.textPrimary
                                font.family: theme.font
                                font.pixelSize: 14
                                font.weight: Font.ExtraBold
                            }

                            Column {
                                id: contentCol
                                visible: !resultsRegion.empty
                                x: 8
                                y: 8
                                width: parent.width - 16
                                spacing: 4

                                Item {
                                    visible: LauncherController.filteredApps.length > 0
                                    width: parent.width
                                    height: 22

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Anwendungen"
                                        color: theme.ink
                                        font.family: theme.font
                                        font.pixelSize: 12
                                        font.weight: Font.ExtraBold
                                        font.capitalization: Font.AllUppercase
                                        font.letterSpacing: 0.5
                                    }

                                    // Selection index / result count for the current query.
                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (LauncherController.activeIndex + 1) + "/" + LauncherController.filteredApps.length
                                        color: theme.textMuted
                                        font.family: theme.font
                                        font.pixelSize: 12
                                        font.weight: Font.ExtraBold
                                    }
                                }

                                // ListView + neobrutalist scrollbar overlay.
                                Item {
                                    id: listWrap
                                    width: parent.width
                                    height: resultsList.height

                                    // True while content overflows the visible window.
                                    readonly property bool scrollable: resultsList.contentHeight > resultsList.height + 1

                                ListView {
                                    id: resultsList
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    // Reserve gutter for the scrollbar only when it shows.
                                    anchors.rightMargin: listWrap.scrollable ? 14 : 0
                                    height: Math.min(contentHeight, launcherScope.maxVisibleRows * launcherScope.rowHeight)
                                    clip: true
                                    model: LauncherController.filteredApps
                                    boundsBehavior: Flickable.StopAtBounds
                                    spacing: 4

                                    // Shared wheel step: ~1.5 rows per notch, mouse + touchpad.
                                    StepWheel {
                                        target: resultsList
                                        rowStride: launcherScope.rowHeight + resultsList.spacing
                                    }

                                    // Controller owns selection; scroll it into view here.
                                    Connections {
                                        target: LauncherController
                                        function onActiveIndexChanged() {
                                            resultsList.positionViewAtIndex(LauncherController.activeIndex, ListView.Contain);
                                        }
                                        function onLauncherVisibleChanged() {
                                            if (LauncherController.launcherVisible)
                                                resultsList.positionViewAtBeginning();
                                        }
                                    }

                                    delegate: Item {
                                        id: del
                                        required property var modelData
                                        required property int index
                                        readonly property bool active: LauncherController.activeIndex === index
                                        readonly property bool lit: active || hov.hovered || tap.pressed
                                        width: resultsList.width
                                        height: launcherScope.rowHeight

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 4
                                            color: tap.pressed ? theme.selPressed : del.active ? theme.selAccent : hov.hovered ? Colors.hoverItemHovered : "transparent"
                                            border.width: del.lit ? 2 : 0
                                            border.color: theme.ink
                                        }

                                        // Bordered icon tile.
                                        Rectangle {
                                            id: iconFrame
                                            width: 28
                                            height: 28
                                            radius: 5
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: theme.paper
                                            border.width: 2
                                            border.color: theme.ink

                                            Image {
                                                id: icon
                                                anchors.centerIn: parent
                                                width: 18
                                                height: 18
                                                source: modelData.app.icon ? ("image://icon/" + modelData.app.icon) : ""
                                                sourceSize: Qt.size(width, width)
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                visible: icon.status !== Image.Ready
                                                text: modelData.app.name && modelData.app.name.length ? modelData.app.name[0].toUpperCase() : "?"
                                                color: theme.ink
                                                font.family: theme.font
                                                font.pixelSize: 13
                                                font.weight: Font.Black
                                            }
                                        }

                                        Text {
                                            id: accessory
                                            anchors.right: parent.right
                                            anchors.rightMargin: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.app.comment || modelData.app.genericName || "Anwendung"
                                            color: theme.textMuted
                                            font.family: theme.font
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                            width: Math.min(implicitWidth, del.width / 3)
                                        }

                                        Text {
                                            anchors.left: iconFrame.right
                                            anchors.leftMargin: 12
                                            anchors.right: accessory.left
                                            anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.query ? FzfLib.highlightHtml(modelData.app.name, modelData.query) : (modelData.app.name || "")
                                            textFormat: modelData.query ? Text.RichText : Text.PlainText
                                            color: theme.textPrimary
                                            font.family: theme.font
                                            font.pixelSize: 14
                                            font.weight: Font.ExtraBold
                                            elide: Text.ElideRight
                                        }

                                        HoverHandler {
                                            id: hov
                                            cursorShape: Qt.PointingHandCursor
                                            onHoveredChanged: {
                                                if (hovered && !LauncherController.kbdLock)
                                                    LauncherController.activeIndex = del.index;
                                            }
                                        }

                                        TapHandler {
                                            id: tap
                                            onTapped: LauncherController.launchApp(del.modelData.app)
                                        }
                                    }
                                }

                                    // Shared draggable handle. Neo defaults (cream track,
                                    // ink border/handle, accent on press) apply since neo is active.
                                    ScrollHandle {
                                        target: resultsList
                                        visible: listWrap.scrollable
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 3
                            color: theme.ink
                        }

                        // Action bar.
                        Item {
                            width: parent.width
                            height: 46

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Image {
                                    width: 16
                                    height: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: LauncherController.selectedApp && LauncherController.selectedApp.icon
                                    source: LauncherController.selectedApp && LauncherController.selectedApp.icon ? ("image://icon/" + LauncherController.selectedApp.icon) : ""
                                    sourceSize: Qt.size(width, width)
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: LauncherController.selectedApp ? LauncherController.selectedApp.name : "Kein Treffer"
                                    color: LauncherController.selectedApp ? theme.textPrimary : theme.textMuted
                                    font.family: theme.font
                                    font.pixelSize: 12
                                    font.weight: Font.ExtraBold
                                }
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Öffnen"
                                        color: theme.textMuted
                                        font.family: theme.font
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }
                                    Item {
                                        anchors.verticalCenter: parent.verticalCenter
                                        implicitWidth: openPill.implicitWidth + 2
                                        implicitHeight: openPill.implicitHeight + 2

                                        Rectangle {
                                            x: 2
                                            y: 2
                                            width: openPill.implicitWidth
                                            height: openPill.implicitHeight
                                            radius: 3
                                            color: theme.ink
                                        }
                                        Rectangle {
                                            id: openPill
                                            radius: 3
                                            color: theme.selAccent
                                            border.width: 2
                                            border.color: theme.ink
                                            implicitWidth: Math.max(22, openKey.implicitWidth + 14)
                                            implicitHeight: 22

                                            Text {
                                                id: openKey
                                                anchors.centerIn: parent
                                                text: "↵"
                                                color: theme.ink
                                                font.family: theme.font
                                                font.pixelSize: 12
                                                font.weight: Font.Black
                                            }
                                        }
                                    }
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Schließen"
                                        color: theme.textMuted
                                        font.family: theme.font
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }
                                    Item {
                                        anchors.verticalCenter: parent.verticalCenter
                                        implicitWidth: escPill.implicitWidth + 2
                                        implicitHeight: escPill.implicitHeight + 2

                                        Rectangle {
                                            x: 2
                                            y: 2
                                            width: escPill.implicitWidth
                                            height: escPill.implicitHeight
                                            radius: 3
                                            color: theme.ink
                                        }
                                        Rectangle {
                                            id: escPill
                                            radius: 3
                                            color: theme.selAccent
                                            border.width: 2
                                            border.color: theme.ink
                                            implicitWidth: Math.max(22, escKey.implicitWidth + 14)
                                            implicitHeight: 22

                                            Text {
                                                id: escKey
                                                anchors.centerIn: parent
                                                text: "Esc"
                                                color: theme.ink
                                                font.family: theme.font
                                                font.pixelSize: 12
                                                font.weight: Font.Black
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
