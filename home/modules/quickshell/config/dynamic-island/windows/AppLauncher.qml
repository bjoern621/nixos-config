import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import "../"
import "../base"
import "../lib/fzf.js" as FzfLib

// Classic launcher view: glass chrome, list. Pure presentation.
// All behavior (app index, fzf, selection, launch, toggle, shortcut) lives in
// the LauncherController singleton. The neo-only readout data (resultCount,
// activeIndex) is simply not shown here.
Scope {
    id: launcherScope

    readonly property int rowHeight: 44
    readonly property int maxVisibleRows: 8

    PanelWindow {
        id: launcherWindow
        visible: Globals.launcherVisible
        WlrLayershell.namespace: "quickshell-launcher"
        screen: Quickshell.screens.find(s => s.name === Globals.launcherScreenName) ?? null

        // No anchors: the compositor centers a card-sized surface.
        implicitWidth: panel.surfaceWidth
        implicitHeight: panel.surfaceHeight

        exclusiveZone: 0
        focusable: true
        WlrLayershell.keyboardFocus: Globals.launcherVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        LauncherDismiss {
            hostWindow: launcherWindow
            watch: panel
            active: Globals.launcherVisible
            onDismissed: Globals.launcherVisible = false
        }

        LauncherPanel {
            id: panel
            anchors.fill: parent
            searchText: LauncherController.searchText
            placeholder: "Suchen..."
            contentMaxHeight: launcherScope.maxVisibleRows * launcherScope.rowHeight
            emptyVisible: LauncherController.resultCount === 0 && LauncherController.searchText !== ""

            onSearchEdited: text => LauncherController.searchText = text
            onEscaped: Globals.launcherVisible = false
            onAccepted: LauncherController.launchSelected()
            onNavigated: (dx, dy) => {
                if (dy !== 0)
                    LauncherController.move(dy);
            }

            LauncherListView {
                id: resultsList
                // Reserve a gutter for the scroll handle only while it shows.
                width: parent.width - (scrollable ? Spacing.scrollGutter : 0)
                height: Math.min(contentHeight, launcherScope.maxVisibleRows * launcherScope.rowHeight)
                model: LauncherController.filteredApps
                rowStride: launcherScope.rowHeight

                // Selection lives here; the controller reads it back as activeIndex.
                // Guarded clear: on a theme switch the replacement view may register first.
                Component.onCompleted: LauncherController.selectionView = resultsList
                Component.onDestruction: {
                    if (LauncherController.selectionView === resultsList)
                        LauncherController.selectionView = null;
                }

                Connections {
                    target: LauncherController
                    function onLauncherVisibleChanged() {
                        if (LauncherController.launcherVisible) {
                            resultsList.cancelFlick();
                            resultsList.positionViewAtBeginning();
                            resultsList.reset();
                        }
                    }
                }

                delegate: Item {
                    id: delegateRoot
                    required property var modelData
                    required property int index
                    readonly property bool active: LauncherController.activeIndex === index
                    width: resultsList.width
                    height: launcherScope.rowHeight

                    LauncherDelegateBg {
                        active: delegateRoot.active
                        pressed: delegateTap.pressed
                    }

                    Image {
                        id: appIcon
                        width: Typography.fontSize24
                        height: width
                        anchors.left: parent.left
                        anchors.leftMargin: Spacing.spacing12
                        anchors.verticalCenter: parent.verticalCenter
                        source: modelData.app.icon ? ("image://icon/" + modelData.app.icon) : ""
                        sourceSize: Qt.size(width, width)
                    }

                    TintedIcon {
                        // Fallback for apps with a missing or unresolvable icon.
                        anchors.fill: appIcon
                        source: "../icons/icons8-desktop.svg"
                        size: Typography.fontSize16
                        color: Colors.textColorMuted
                        visible: appIcon.status !== Image.Ready
                    }

                    Column {
                        anchors.left: appIcon.right
                        anchors.leftMargin: Spacing.spacing12
                        anchors.right: parent.right
                        anchors.rightMargin: Spacing.spacing12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Spacing.spacing2

                        Label {
                            text: modelData.query ? FzfLib.highlightHtml(modelData.app.name, modelData.query) : (modelData.app.name || "")
                            textFormat: modelData.query ? Text.RichText : Text.PlainText
                            width: parent.width
                            elide: Text.ElideRight
                        }

                        Label {
                            text: modelData.query && modelData.app.comment ? FzfLib.highlightHtml(modelData.app.comment, modelData.query) : (modelData.app.comment || "")
                            textFormat: modelData.query ? Text.RichText : Text.PlainText
                            font.pixelSize: Typography.fontSize12
                            font.weight: Font.Normal
                            color: Colors.textColorMuted
                            width: parent.width
                            elide: Text.ElideRight
                            visible: (modelData.app.comment || "") !== ""
                        }
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: delegateTap
                        onTapped: LauncherController.launchApp(delegateRoot.modelData.app)
                    }
                }
            }

            // Shared draggable handle, sibling of the list.
            ScrollHandle {
                target: resultsList
                visible: resultsList.scrollable
                anchors.right: parent.right
                anchors.top: resultsList.top
                anchors.bottom: resultsList.bottom
            }
        }
    }
}
