import Quickshell
import Quickshell.Hyprland
import Quickshell.Hyprland._GlobalShortcuts
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import "../"
import "../base"

// Alt+Tab window switcher, Windows-style.
// Alt+Tab steps forward, Alt+Shift+Tab back, Alt release focuses the selection, Escape cancels.
// Hyprland owns all four keys and submap `alttab` (hyprland/window-switcher.lua):
// Alt+Tab never reaches a client, so the surface takes no keyboard focus.
// Alt release comes from a Lua key listener.
// Overlay with keyboard focus misses a release that lands before it maps.
//
// Order is most recently focused first, so one Alt+Tab lands on the previous window.
// Quick tap commits before showDelay runs out and never maps the card.
Scope {
    id: root

    readonly property int rowHeight: 48
    readonly property int maxVisibleRows: 10
    readonly property int panelWidth: 520
    // Delay before card maps.
    // Quick Alt+Tab tap switches without a flash.
    readonly property int showDelay: 100

    // Switch in progress: Alt+Tab pressed, Alt not yet released.
    property bool active: false
    property bool shown: false
    property bool loading: false
    property var windows: []
    property int index: 0
    // Steps and commit arriving while hyprctl still runs.
    property int pendingSteps: 0
    property bool commitPending: false

    function step(delta) {
        if (!active) {
            active = true;
            loading = true;
            pendingSteps = delta;
            commitPending = false;
            index = 0;
            const mon = Hyprland.focusedMonitor;
            const s = mon ? Quickshell.screens.find(sc => sc.name === mon.name) : null;
            if (s)
                switcherWindow.screen = s;
            showTimer.restart();
            clientsProc.running = true;
            return;
        }
        if (loading) {
            pendingSteps += delta;
            return;
        }
        root._move(delta);
    }

    function _move(delta) {
        const n = windows.length;
        if (n === 0)
            return;
        index = ((index + delta) % n + n) % n;
        list.positionViewAtIndex(index, ListView.Contain);
    }

    function commit() {
        if (!active)
            return;
        if (loading) {
            commitPending = true;
            return;
        }
        const w = windows[index];
        root.close();
        if (w)
            WindowFocus.focusAddress(w.address);
    }

    function close() {
        if (active)
            Hyprland.dispatch('hl.dsp.submap("reset")');
        showTimer.stop();
        active = false;
        shown = false;
        loading = false;
    }

    function _load(text) {
        let clients = [];
        try {
            clients = JSON.parse(text);
        } catch (e) {
            console.warn("[WindowSwitcher] hyprctl clients -j:", e);
        }
        // focusHistoryID 0 is the focused window; -1 never had focus.
        const list = clients.filter(c => c.mapped && !c.hidden && c.address).sort((a, b) => {
            const fa = a.focusHistoryID < 0 ? 1e9 : a.focusHistoryID;
            const fb = b.focusHistoryID < 0 ? 1e9 : b.focusHistoryID;
            return fa - fb;
        }).map(c => {
            const entry = DesktopEntries.heuristicLookup(c.class || c.initialClass || "");
            return {
                address: c.address,
                title: c.title || c.class || "",
                appName: entry ? entry.name : (c.class || ""),
                icon: Quickshell.iconPath(entry && entry.icon ? entry.icon : (c.class || ""), true),
                workspace: c.workspace ? c.workspace.name : ""
            };
        });
        windows = list;
        loading = false;
        if (list.length === 0) {
            root.close();
            return;
        }
        // Start on the focused window, one step lands on the previous one.
        index = 0;
        root._move(pendingSteps);
        if (commitPending)
            root.commit();
    }

    Timer {
        id: showTimer
        interval: root.showDelay
        onTriggered: root.shown = root.active
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        // StdioCollector, not SplitParser: output outgrows one pipe read.
        stdout: StdioCollector {
            id: clientsOut
            onStreamFinished: {
                if (root.active)
                    root._load(clientsOut.text);
            }
        }
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "alttab-next"
        description: "Window switcher: next window"
        onPressed: root.step(1)
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "alttab-prev"
        description: "Window switcher: previous window"
        onPressed: root.step(-1)
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "alttab-commit"
        description: "Window switcher: focus selection (Alt release)"
        onPressed: root.commit()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "alttab-cancel"
        description: "Window switcher: cancel (Escape)"
        onPressed: root.close()
    }

    IpcHandler {
        target: "alttab"
        function next() {
            root.step(1);
        }
        function prev() {
            root.step(-1);
        }
        function commit() {
            root.commit();
        }
        function cancel() {
            root.close();
        }
    }

    PanelWindow {
        id: switcherWindow
        // Session fixes window list, so size holds until close.
        // List survives close: hide animation keeps its rows.
        visible: reveal.showing || !hideComplete
        property bool hideComplete: true
        color: "transparent"
        exclusiveZone: 0
        // No anchors: compositor centers card-sized surface.
        implicitWidth: card.width
        implicitHeight: card.height
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Same reveal as ModalOverlay.
        PopReveal {
            id: reveal
            anchors.fill: parent
            showing: root.shown && !root.loading && root.windows.length > 0
            slideOffset: 0
            showDuration: 100
            hideDuration: 80
            enabled: showing
            onShowingChanged: {
                if (showing)
                    switcherWindow.hideComplete = false;
            }
            onHidden: switcherWindow.hideComplete = true

            Card {
                id: card
                width: root.panelWidth + Shape.shadowOffset
                height: list.height + 2 * Spacing.spacing8 + Shape.shadowOffset

                ListView {
                    id: list
                    x: Spacing.spacing8
                    y: Spacing.spacing8
                    width: card.paperWidth - 2 * Spacing.spacing8
                    height: Math.min(count, root.maxVisibleRows) * root.rowHeight
                    model: root.windows
                    interactive: count > root.maxVisibleRows
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width
                        height: root.rowHeight

                        LauncherDelegateBg {
                            active: root.index === row.index
                            hovered: rowHover.hovered
                            pressed: rowTap.pressed
                        }

                        Image {
                            id: appIcon
                            width: Typography.fontSize24
                            height: width
                            anchors.left: parent.left
                            anchors.leftMargin: Spacing.spacing12
                            anchors.verticalCenter: parent.verticalCenter
                            source: row.modelData.icon
                            sourceSize: Qt.size(width, width)
                        }

                        TintedIcon {
                            // Fallback for unresolvable icon.
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
                                text: row.modelData.title
                                width: parent.width
                                elide: Text.ElideRight
                            }

                            Label {
                                text: row.modelData.appName + (row.modelData.workspace ? "  ·  Workspace " + row.modelData.workspace : "")
                                font.pixelSize: Typography.fontSize12
                                font.weight: Font.Normal
                                color: Colors.textColorMuted
                                width: parent.width
                                elide: Text.ElideRight
                            }
                        }

                        // Hover highlights only.
                        // Card mapping under stationary cursor must not steal selection.
                        HoverHandler {
                            id: rowHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            id: rowTap
                            onTapped: {
                                root.index = row.index;
                                root.commit();
                            }
                        }
                    }
                }
            }
        }
    }
}
