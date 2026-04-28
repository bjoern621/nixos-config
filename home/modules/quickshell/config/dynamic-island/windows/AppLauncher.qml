import Quickshell
import Quickshell.Hyprland
import Quickshell.Hyprland._GlobalShortcuts
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import "../"
import "../base"
import "../lib/fzf.js" as FzfLib

Scope {
    id: launcherScope

    readonly property int maxResults: 50
    readonly property int rowHeight: 44
    readonly property int maxVisibleRows: 8
    // Per-field weights: name dominates, comment is tiebreaker.
    readonly property var fieldWeights: [3.0, 1.5, 1.2, 0.7]

    property bool launcherVisible: false
    property string searchText: ""
    // Each entry: { app, fields:[4], lower:[4] }
    property var indexedApps: []
    property var filteredApps: []

    onLauncherVisibleChanged: {
        Globals.launcherVisible = launcherVisible;
        if (launcherVisible) {
            searchText = "";
            updateFilter();
        }
    }

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
            filteredApps = indexedApps.slice(0, maxResults).map(e => ({
                app: e.app,
                query: ""
            }));
            resultsList.currentIndex = 0;
            return;
        }

        const weights = fieldWeights;
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

        const limit = Math.min(scored.length, maxResults);
        const out = new Array(limit);
        for (let i = 0; i < limit; i++)
            out[i] = {
                app: scored[i].app,
                query: query
            };
        filteredApps = out;
        resultsList.currentIndex = 0;
    }

    function launchApp(app) {
        launcherVisible = false;
        Quickshell.execDetached(["uwsm", "app", "--", app.id + ".desktop"]);
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

    Component.onCompleted: rebuildAppList()

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            launcherScope.rebuildAppList();
            launcherScope.updateFilter();
        }
    }

    // Hyprland delivers SUPER tap directly to this running quickshell process
    // via the wlr global-shortcuts protocol. Bypasses the `qs ipc` CLI which
    // costs ~125ms per call (Qt binary cold start).
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

        LauncherPanel {
            anchors.fill: parent
            searchText: launcherScope.searchText
            placeholder: "Suchen..."
            emptyVisible: launcherScope.filteredApps.length === 0 && launcherScope.searchText !== ""

            onSearchEdited: text => launcherScope.searchText = text
            onEscaped: launcherScope.launcherVisible = false
            onAccepted: {
                const apps = launcherScope.filteredApps;
                if (apps.length > 0)
                    launcherScope.launchApp(apps[resultsList.currentIndex].app);
            }
            onNavigated: (dx, dy) => {
                if (dy === 0)
                    return;
                resultsList.keyboardNav = true;
                const next = resultsList.currentIndex + dy;
                if (next >= 0 && next < launcherScope.filteredApps.length)
                    resultsList.currentIndex = next;
            }

            LauncherListView {
                id: resultsList
                width: parent.width
                height: Math.min(contentHeight, launcherScope.maxVisibleRows * launcherScope.rowHeight)
                model: launcherScope.filteredApps

                delegate: Item {
                    id: delegateRoot
                    required property var modelData
                    required property int index
                    readonly property bool active: resultsList.currentIndex === index || delegateHover.hovered
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
                        onTapped: launcherScope.launchApp(delegateRoot.modelData.app)
                    }
                }
            }
        }
    }
}
