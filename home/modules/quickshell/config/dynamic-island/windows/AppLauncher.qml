import Quickshell
import Quickshell.Hyprland
import Quickshell.Hyprland._GlobalShortcuts
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import QtQuick.Controls
import "../"
import "../base"
import "../lib/fzf.js" as FzfLib

Scope {
    id: launcherScope

    readonly property int maxResults: 50
    // Per-field weights. Name dominates, comment is tiebreaker only.
    readonly property var fieldWeights: [3.0, 1.5, 1.2, 0.7]

    property bool launcherVisible: false

    onLauncherVisibleChanged: {
        Globals.launcherVisible = launcherVisible;
        if (launcherVisible) {
            launcherWindow.searchText = "";
            resultsList.contentY = 0;
            resultsList.keyboardNav = false;
            launcherWindow.updateFilter();
        }
    }

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor;
        return mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? null) : null;
    }

    function toggle() {
        if (!launcherVisible) {
            const s = focusedScreen();
            if (s)
                launcherWindow.screen = s;
        }
        launcherVisible = !launcherVisible;
    }

    // Hyprland delivers SUPER tap directly to this running quickshell process
    // via the wlr global-shortcuts protocol. Bypasses the `qs ipc` CLI which
    // costs ~125ms per call (Qt binary cold start).
    // Bound from app-launcher.nix as: bind = , Super_L, global, quickshell:launcher
    // No SUPER mod prefix: Hyprland only dispatches the bare Super_L keycode on
    // solo press; combos like SUPER+q route through the SUPER+keycode path instead.
    GlobalShortcut {
        appid: "quickshell"
        name: "launcher"
        description: "Toggle the app launcher"
        onPressed: launcherScope.toggle()
    }

    IpcHandler {
        target: "launcher"
        function toggle() {
            launcherScope.toggle();
        }
    }

    PanelWindow {
        id: launcherWindow
        visible: launcherScope.launcherVisible
        WlrLayershell.namespace: "quickshell-launcher"

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        exclusiveZone: 0
        focusable: true
        WlrLayershell.keyboardFocus: launcherScope.launcherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        readonly property int rowHeight: 44
        readonly property int maxVisibleRows: 8

        property string searchText: ""
        // Each entry: { app, fields: [string,string,string,string], lower: [string,string,string,string] }
        property var indexedApps: []
        property var filteredApps: []

        onSearchTextChanged: updateFilter()

        function rebuildAppList() {
            const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name));
            indexedApps = apps.map(app => {
                const kw = app.keywords;
                const keywords = Array.isArray(kw) ? kw.join(" ") : (typeof kw === "string" ? kw : "");
                const fields = [app.name || "", app.genericName || "", keywords, app.comment || ""];
                return {
                    app,
                    fields,
                    lower: fields.map(f => f.toLowerCase())
                };
            });
        }

        function updateFilter() {
            const query = searchText.toLowerCase();
            if (query === "") {
                filteredApps = indexedApps.slice(0, launcherScope.maxResults).map(e => ({
                    app: e.app,
                    query: ""
                }));
                resultsList.currentIndex = 0;
                return;
            }

            const weights = launcherScope.fieldWeights;
            const scored = [];
            for (let i = 0; i < indexedApps.length; i++) {
                const e = indexedApps[i];
                let best = -Infinity;
                for (let f = 0; f < e.fields.length; f++) {
                    const raw = FzfLib.scoreLower(e.fields[f], e.lower[f], query);
                    if (raw === -Infinity)
                        continue;
                    const weighted = raw * weights[f];
                    if (weighted > best)
                        best = weighted;
                }
                if (best > -Infinity)
                    scored.push({
                        app: e.app,
                        score: best
                    });
            }
            scored.sort((a, b) => b.score - a.score || a.app.name.localeCompare(b.app.name));

            const out = [];
            const limit = Math.min(scored.length, launcherScope.maxResults);
            for (let i = 0; i < limit; i++)
                out.push({
                    app: scored[i].app,
                    query: query
                });
            filteredApps = out;
            resultsList.currentIndex = 0;
        }

        function launchApp(app) {
            launcherScope.launcherVisible = false;
            Quickshell.execDetached(["uwsm", "app", "--", app.id + ".desktop"]);
        }

        Component.onCompleted: rebuildAppList()

        Connections {
            target: DesktopEntries
            function onApplicationsChanged() {
                launcherWindow.rebuildAppList();
                launcherWindow.updateFilter();
            }
        }

        Item {
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                const k = event.key;
                const ctrl = event.modifiers & Qt.ControlModifier;
                if (k === Qt.Key_Escape) {
                    launcherScope.launcherVisible = false;
                } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                    const apps = launcherWindow.filteredApps;
                    if (apps.length > 0)
                        launcherWindow.launchApp(apps[resultsList.currentIndex].app);
                } else if (k === Qt.Key_Down || k === Qt.Key_Up) {
                    resultsList.keyboardNav = true;
                    const next = resultsList.currentIndex + (k === Qt.Key_Down ? 1 : -1);
                    if (next >= 0 && next < launcherWindow.filteredApps.length)
                        resultsList.currentIndex = next;
                } else if (k === Qt.Key_Backspace) {
                    launcherWindow.searchText = ctrl ? launcherWindow.searchText.replace(/\S+\s*$/, "") : launcherWindow.searchText.slice(0, -1);
                } else if (k === Qt.Key_Delete || (k === Qt.Key_A && ctrl)) {
                    launcherWindow.searchText = "";
                } else if (event.text && event.text.length > 0 && !ctrl) {
                    launcherWindow.searchText += event.text;
                }
                event.accepted = true;
            }

            // Click-to-dismiss (transparent, no dim)
            TapHandler {
                onTapped: launcherScope.launcherVisible = false
            }

            Rectangle {
                id: panel
                width: 500
                height: contentColumn.implicitHeight + 2 * Spacing.spacing12
                anchors.centerIn: parent

                radius: Spacing.spacing12
                color: Colors.pillBackground
                border.width: 1
                border.color: Colors.pillBorder

                Column {
                    id: contentColumn
                    anchors {
                        fill: parent
                        margins: Spacing.spacing12
                    }
                    spacing: Spacing.spacing8

                    Rectangle {
                        width: parent.width
                        height: 40
                        radius: Spacing.spacing8
                        color: Colors.hoverItemHovered
                        border.width: 1
                        border.color: Colors.accentColor

                        TintedIcon {
                            id: searchIcon
                            source: "../icons/icons8-search.svg"
                            size: Typography.fontSize14
                            color: Colors.textColorMuted
                            anchors.left: parent.left
                            anchors.leftMargin: Spacing.spacing12
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            anchors.left: searchIcon.right
                            anchors.leftMargin: Spacing.spacing8
                            anchors.right: parent.right
                            anchors.rightMargin: Spacing.spacing12
                            anchors.verticalCenter: parent.verticalCenter
                            color: launcherWindow.searchText ? Colors.textColor : Colors.textColorMuted
                            clip: true
                            font.weight: Font.Medium
                            text: launcherWindow.searchText || "Suchen..."
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    ListView {
                        id: resultsList
                        width: parent.width
                        height: Math.min(contentHeight, launcherWindow.maxVisibleRows * launcherWindow.rowHeight)
                        clip: true
                        currentIndex: 0
                        model: launcherWindow.filteredApps
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 0

                        property bool keyboardNav: false

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: true
                            propagateComposedEvents: true
                            function syncHover() {
                                resultsList.keyboardNav = false;
                                const item = resultsList.itemAt(resultsList.contentX + mouseX, resultsList.contentY + mouseY);
                                if (item && item.index !== undefined)
                                    resultsList.currentIndex = item.index;
                            }
                            onPositionChanged: syncHover()
                            onWheel: wheel => {
                                resultsList.contentY = Math.max(0, Math.min(Math.max(0, resultsList.contentHeight - resultsList.height), resultsList.contentY - wheel.angleDelta.y * 2));
                                syncHover();
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: resultsList.contentHeight > resultsList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                            contentItem: Rectangle {
                                implicitWidth: 4
                                radius: width / 2
                                color: Colors.textColorMuted
                                opacity: parent.active ? 0.6 : 0.3
                            }
                        }

                        delegate: Item {
                            id: delegateRoot
                            required property var modelData
                            required property int index
                            readonly property bool active: resultsList.currentIndex === index || delegateHover.hovered
                            width: resultsList.width
                            height: launcherWindow.rowHeight

                            Rectangle {
                                anchors.fill: parent
                                radius: Spacing.spacing8
                                color: delegateTap.pressed ? Colors.hoverItemPressed : delegateRoot.active ? Colors.hoverItemHovered : "transparent"
                                border.color: delegateRoot.active || delegateTap.pressed ? Colors.pillBorder : "transparent"
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
                                anchors.fill: appIcon
                                source: "../icons/icons8-menu.svg"
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
                                id: delegateHover
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: {
                                    if (hovered && !resultsList.keyboardNav)
                                        resultsList.currentIndex = delegateRoot.index;
                                }
                            }

                            TapHandler {
                                id: delegateTap
                                onTapped: launcherWindow.launchApp(delegateRoot.modelData.app)
                            }
                        }
                    }

                    Label {
                        visible: launcherWindow.filteredApps.length === 0 && launcherWindow.searchText !== ""
                        text: "Keine Ergebnisse"
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: Spacing.spacing8
                        bottomPadding: Spacing.spacing8
                    }
                }
            }
        }
    }
}
