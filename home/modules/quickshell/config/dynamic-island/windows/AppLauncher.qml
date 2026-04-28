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

    property bool launcherVisible: false
    onLauncherVisibleChanged: Globals.launcherVisible = launcherVisible

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor;
        if (mon) {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === mon.name)
                    return screens[i];
            }
        }
        return null;
    }

    function toggle() {
        if (!launcherScope.launcherVisible) {
            const s = launcherScope.focusedScreen();
            if (s)
                launcherWindow.screen = s;
        }
        launcherScope.launcherVisible = !launcherScope.launcherVisible;
    }

    // Hyprland delivers SUPER tap directly to this running quickshell process
    // via the wlr global-shortcuts protocol. Bypasses the `qs ipc` CLI which
    // costs ~125ms per call (Qt binary cold start).
    // Bound from app-launcher.nix as: bind = SUPER, Super_L, global, quickshell:launcher
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

        mask: Region {
            item: launcherScope.launcherVisible ? fullArea : emptyMask
        }

        Item {
            id: emptyMask
            width: 0
            height: 0
        }

        property var allApps: []
        property var filteredApps: []

        // Per-field weights. Name dominates, comment is tiebreaker only.
        readonly property var fieldWeights: [3.0, 1.5, 1.2, 0.7]

        function rebuildAppList() {
            const apps = DesktopEntries.applications;
            let list = [];

            for (let i = 0; i < apps.values.length; i++) {
                const app = apps.values[i];
                if (app.noDisplay)
                    continue;
                list.push(app);
            }

            list.sort((a, b) => a.name.localeCompare(b.name));
            allApps = list;
        }

        function appFields(app) {
            let keywords = "";
            const kw = app.keywords;
            if (kw && typeof kw !== "string" && kw.length !== undefined) {
                const arr = [];
                for (let i = 0; i < kw.length; i++) arr.push(kw[i]);
                keywords = arr.join(" ");
            } else if (typeof kw === "string") {
                keywords = kw;
            }
            return [app.name || "", app.genericName || "", keywords, app.comment || ""];
        }

        function updateFilter() {
            const query = searchInput.text.toLowerCase();
            if (query === "") {
                filteredApps = allApps.slice(0, 50);
                resultsList.currentIndex = 0;
                return;
            }

            const weights = fieldWeights;
            let scored = [];
            for (let i = 0; i < allApps.length; i++) {
                const app = allApps[i];
                const fields = appFields(app);
                let best = -Infinity;
                for (let f = 0; f < fields.length; f++) {
                    const raw = FzfLib.scoreText(fields[f], query);
                    if (raw === -Infinity) continue;
                    const weighted = raw * weights[f];
                    if (weighted > best) best = weighted;
                }
                if (best > -Infinity) scored.push([best, app]);
            }
            scored.sort((a, b) => {
                if (b[0] !== a[0]) return b[0] - a[0];
                return a[1].name.localeCompare(b[1].name);
            });
            const out = [];
            for (let i = 0; i < scored.length && i < 50; i++) out.push(scored[i][1]);
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
            id: fullArea
            anchors.fill: parent
            focus: true

            // Hidden TextInput for text editing logic (never rendered, no surface association)
            TextInput {
                id: searchInput
                visible: false
                focus: false

                onTextChanged: launcherWindow.updateFilter()
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    launcherScope.launcherVisible = false;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (launcherWindow.filteredApps.length > 0)
                        launcherWindow.launchApp(launcherWindow.filteredApps[resultsList.currentIndex]);
                } else if (event.key === Qt.Key_Down) {
                    resultsList.keyboardNav = true;
                    if (resultsList.currentIndex < launcherWindow.filteredApps.length - 1)
                        resultsList.currentIndex++;
                } else if (event.key === Qt.Key_Up) {
                    resultsList.keyboardNav = true;
                    if (resultsList.currentIndex > 0)
                        resultsList.currentIndex--;
                } else if (event.key === Qt.Key_Backspace) {
                    if (event.modifiers & Qt.ControlModifier)
                        searchInput.text = searchInput.text.replace(/\S+\s*$/, "");
                    else
                        searchInput.text = searchInput.text.slice(0, -1);
                } else if (event.key === Qt.Key_Delete) {
                    searchInput.text = "";
                } else if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
                    searchInput.text = "";
                } else if (event.text && event.text.length > 0 && !(event.modifiers & Qt.ControlModifier)) {
                    searchInput.text += event.text;
                }
                event.accepted = true;
            }

            // Click-to-dismiss (transparent, no dim)
            TapHandler {
                onTapped: launcherScope.launcherVisible = false
            }

            Item {
                id: panelReveal
                width: 500
                height: panel.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                visible: launcherScope.launcherVisible

                Rectangle {
                    id: panel
                    anchors.fill: parent
                    implicitHeight: contentColumn.implicitHeight + 2 * Spacing.spacing12

                    radius: Spacing.spacing12
                    color: Colors.pillBackground
                    border.width: 1
                    border.color: Colors.pillBorder
                }

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
                        border.color: launcherScope.launcherVisible ? Colors.accentColor : Colors.pillBorder

                        Row {
                            anchors {
                                fill: parent
                                leftMargin: Spacing.spacing12
                                rightMargin: Spacing.spacing12
                            }
                            spacing: Spacing.spacing8

                            TintedIcon {
                                source: "../icons/icons8-search.svg"
                                size: Typography.fontSize14
                                color: Colors.textColorMuted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                width: parent.width - Typography.fontSize14 - Spacing.spacing8 - 2 * Spacing.spacing12
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: Typography.fontFamily
                                font.pixelSize: Typography.fontSize14
                                font.weight: Font.Bold
                                color: searchInput.text ? Colors.textColor : Colors.textColorMuted
                                clip: true
                                text: searchInput.text || "Suchen..."
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    ListView {
                        id: resultsList
                        width: parent.width
                        height: Math.min(contentHeight, 8 * 44)
                        clip: true
                        currentIndex: 0
                        model: launcherWindow.filteredApps
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 0

                        property bool keyboardNav: false

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: true
                            onPositionChanged: resultsList.keyboardNav = false
                            onWheel: wheel => {
                                resultsList.contentY = Math.max(0, Math.min(resultsList.contentHeight - resultsList.height, resultsList.contentY - wheel.angleDelta.y * 2));
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
                            required property var modelData
                            required property int index
                            width: resultsList.width
                            height: 44

                            Rectangle {
                                anchors.fill: parent
                                radius: Spacing.spacing8
                                color: delegateTap.pressed ? Colors.hoverItemPressed : resultsList.currentIndex === index || delegateHover.hovered ? Colors.hoverItemHovered : "transparent"
                                border.color: resultsList.currentIndex === index || delegateHover.hovered || delegateTap.pressed ? Colors.pillBorder : "transparent"
                            }

                            Row {
                                anchors {
                                    fill: parent
                                    leftMargin: Spacing.spacing12
                                    rightMargin: Spacing.spacing12
                                }
                                spacing: Spacing.spacing12

                                Image {
                                    id: appIcon
                                    width: Typography.fontSize24
                                    height: Typography.fontSize24
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: modelData.icon ? ("image://icon/" + modelData.icon) : ""
                                    sourceSize: Qt.size(Typography.fontSize24, Typography.fontSize24)
                                }

                                TintedIcon {
                                    source: "../icons/icons8-menu.svg"
                                    size: Typography.fontSize16
                                    color: Colors.textColorMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Typography.fontSize24
                                    visible: appIcon.status !== Image.Ready
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - Typography.fontSize24 - Spacing.spacing12 - 2 * Spacing.spacing12
                                    spacing: Spacing.spacing2

                                    Text {
                                        text: modelData.name
                                        font.family: Typography.fontFamily
                                        font.pixelSize: Typography.fontSize14
                                        font.weight: Font.Bold
                                        color: Colors.textColor
                                        width: parent.width
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: modelData.comment || ""
                                        font.family: Typography.fontFamily
                                        font.pixelSize: Typography.fontSize12
                                        font.weight: Font.Normal
                                        color: Colors.textColorMuted
                                        width: parent.width
                                        elide: Text.ElideRight
                                        visible: text !== ""
                                    }
                                }
                            }

                            HoverHandler {
                                id: delegateHover
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: {
                                    if (hovered && !resultsList.keyboardNav)
                                        resultsList.currentIndex = index;
                                }
                            }

                            TapHandler {
                                id: delegateTap
                                onTapped: launcherWindow.launchApp(modelData)
                            }
                        }
                    }

                    Text {
                        visible: launcherWindow.filteredApps.length === 0 && searchInput.text !== ""
                        text: "Keine Ergebnisse"
                        font.family: Typography.fontFamily
                        font.pixelSize: Typography.fontSize14
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: Spacing.spacing8
                        bottomPadding: Spacing.spacing8
                    }
                }
            }
        }

        Connections {
            target: launcherScope
            function onLauncherVisibleChanged() {
                if (launcherScope.launcherVisible) {
                    searchInput.text = "";
                    resultsList.contentY = 0;
                    resultsList.keyboardNav = false;
                    launcherWindow.updateFilter();
                }
            }
        }
    }
}
