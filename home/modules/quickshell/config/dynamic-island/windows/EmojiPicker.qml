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
    id: emojiScope

    readonly property int maxResults: 400
    readonly property int cellSize: 44
    readonly property int gridCols: 9
    readonly property int gridRows: 8
    readonly property int categorySize: 36

    property bool emojiVisible: false
    property string searchText: ""
    property int selectedGroup: 0
    // Populated from the worker's "loaded" reply (parsed off-thread).
    property var groups: []
    property var filteredEmojis: []
    property bool dataLoaded: false

    // Filtering runs in emojiWorker off the UI thread. Only one query is in
    // flight at a time: a request arriving mid-query sets queryPending, and the
    // result handler dispatches the latest once the current one returns. Newest
    // query always wins, and no stale intermediate result reaches the grid.
    property bool queryBusy: false
    property bool queryPending: false

    // Tooltip target: set by hovered emoji/category delegate, cleared on exit.
    property Item hoveredCell: null
    property string hoveredText: ""
    property string hoveredSubtitle: ""

    onEmojiVisibleChanged: {
        if (emojiVisible) {
            searchText = "";
            requestFilter();
            emojiScope.rewindGrid();
            emojiGrid.reset();
        } else {
            hoveredCell = null;
        }
    }

    // cancelFlick() kills in-flight wheel momentum from the previous open.
    // positionViewAtBeginning() accounts for originY.
    // contentY = 0 leaves blank space above row 0 while a flick still animates.
    function rewindGrid() {
        emojiGrid.cancelFlick();
        emojiGrid.positionViewAtBeginning();
    }

    onSearchTextChanged: {
        hoveredCell = null;
        requestFilter();
    }
    onSelectedGroupChanged: {
        hoveredCell = null;
        if (searchText === "")
            requestFilter();
        emojiScope.rewindGrid();
        emojiGrid.currentIndex = 0;
        emojiGrid.hoveredIndex = -1;
    }

    // Reads the JSON on the UI thread, hands the raw text to the worker.
    // Parse + index happen off-thread. Reload re-sends, worker rebuilds.
    FileView {
        id: emojiDataFile
        path: Quickshell.env("QUICKSHELL_EMOJI_DATA") || ""
        blockLoading: false
        onLoaded: emojiWorker.sendMessage({
            type: "load",
            text: emojiDataFile.text(),
            // Worker base URL is not lib/, so resolve fzf.js here and pass it in.
            fzfUrl: Qt.resolvedUrl("../lib/fzf.js")
        })
        onLoadFailed: error => console.warn("[EmojiPicker] failed to load:", error)
    }

    WorkerScript {
        id: emojiWorker
        source: "../lib/emoji-worker.js"
        onMessage: msg => {
            if (msg.type === "loaded") {
                if (!msg.ok) {
                    console.warn("[EmojiPicker] worker load failed:", msg.error);
                    return;
                }
                emojiScope.groups = msg.groups;
                emojiScope.dataLoaded = true;
                emojiScope.requestFilter();
            } else if (msg.type === "result") {
                emojiScope.queryBusy = false;
                // A newer query queued while this ran: skip the stale result,
                // dispatch the latest instead of flashing it on the grid.
                if (emojiScope.queryPending) {
                    emojiScope.dispatchQuery();
                    return;
                }
                emojiScope.filteredEmojis = msg.items;
                emojiGrid.currentIndex = 0;
            }
        }
    }

    // Coalesced request: the worker sees one query at a time, always the newest.
    function requestFilter() {
        if (!dataLoaded)
            return;
        if (queryBusy) {
            queryPending = true;
            return;
        }
        dispatchQuery();
    }

    function dispatchQuery() {
        queryBusy = true;
        queryPending = false;
        emojiWorker.sendMessage({
            type: "query",
            query: searchText.toLowerCase(),
            group: selectedGroup,
            maxResults: maxResults
        });
    }

    function selectEmoji(emoji) {
        emojiVisible = false;
        typeProc.emoji = emoji.c;
        typeProc.running = true;
    }

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor;
        return mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? null) : null;
    }

    function toggle() {
        if (!emojiVisible) {
            const s = focusedScreen();
            if (s)
                emojiWindow.screen = s;
        }
        emojiVisible = !emojiVisible;
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "emoji"
        description: "Toggle the emoji picker"
        onPressed: emojiScope.toggle()
    }

    IpcHandler {
        target: "emoji"
        function toggle() {
            emojiScope.toggle();
        }
    }

    Process {
        id: typeProc
        property string emoji: ""
        // Copy the emoji to the clipboard, then paste it into the focused client
        // with Ctrl+Shift+V. The paste is fired from onExited so the copy has
        // landed and the emoji window has unmapped, letting keyboard focus return
        // to the previous client before the keys are injected. Direct `wtype`
        // typing of the codepoints is unreliable across apps (synthetic keymap,
        // ZWJ/skin-tone sequences), so the clipboard route is used instead.
        command: ["bash", "-c", "printf '%s' \"$EMOJI\" | wl-copy"]
        environment: ({
                EMOJI: emoji
            })
        running: false

        onExited: {
            Quickshell.execDetached(["wtype", "-M", "ctrl", "-M", "shift", "v", "-m", "shift", "-m", "ctrl"]);
        }
    }

    PanelWindow {
        id: emojiWindow
        visible: emojiScope.emojiVisible
        WlrLayershell.namespace: "quickshell-emoji"

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        exclusiveZone: 0
        focusable: true
        WlrLayershell.keyboardFocus: emojiScope.emojiVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        AutoCloseOnFocusLoss {
            watch: panel
            armed: emojiScope.emojiVisible
            onLost: emojiScope.emojiVisible = false
        }

        LauncherPanel {
            id: panel
            anchors.fill: parent
            searchText: emojiScope.searchText
            placeholder: "Emoji suchen..."
            // Extra gutter width so all gridCols columns survive next to the bar.
            panelWidth: emojiScope.cellSize * emojiScope.gridCols + 2 * Spacing.spacing12 + Spacing.scrollGutter
            emptyVisible: emojiScope.dataLoaded && emojiScope.filteredEmojis.length === 0 && emojiScope.searchText !== ""

            onSearchEdited: text => emojiScope.searchText = text
            onEscaped: emojiScope.emojiVisible = false
            onAccepted: {
                if (emojiScope.filteredEmojis.length > 0)
                    emojiScope.selectEmoji(emojiScope.filteredEmojis[emojiGrid.effectiveIndex]);
            }
            onNavigated: (dx, dy) => {
                const cols = emojiScope.gridCols;
                const total = emojiScope.filteredEmojis.length;
                let next = emojiGrid.effectiveIndex + dx + dy * cols;
                emojiGrid.keyboardNav = true;
                if (next < 0)
                    next = 0;
                if (next >= total)
                    next = total - 1;
                emojiGrid.currentIndex = next;
            }
            onPageChange: dy => {
                const total = emojiScope.filteredEmojis.length;
                let next = emojiGrid.effectiveIndex + dy * emojiScope.gridCols * emojiScope.gridRows;
                emojiGrid.keyboardNav = true;
                if (next < 0)
                    next = 0;
                if (next >= total)
                    next = total - 1;
                emojiGrid.currentIndex = next;
            }

            Column {
                width: parent.width
                spacing: Spacing.spacing8

                // Wrapper lets the scroll handle overlay the grid's right edge.
                Item {
                    width: parent.width
                    height: emojiGrid.height

                LauncherGridView {
                    id: emojiGrid
                    // Reserve a gutter for the scroll handle only while it shows.
                    width: parent.width - (scrollable ? Spacing.scrollGutter : 0)
                    height: Math.min(contentHeight, emojiScope.cellSize * emojiScope.gridRows)
                    cellWidth: emojiScope.cellSize
                    cellHeight: emojiScope.cellSize
                    model: emojiScope.filteredEmojis

                    delegate: Item {
                        id: emojiCell
                        required property var modelData
                        required property int index
                        readonly property bool active: emojiGrid.effectiveIndex === index
                        width: emojiGrid.cellWidth
                        height: emojiGrid.cellHeight

                        LauncherDelegateBg {
                            active: emojiCell.active
                            pressed: emojiCellTap.pressed
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.c
                            font.pixelSize: Typography.fontSize24
                        }

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (hovered) {
                                    const q = emojiScope.searchText.toLowerCase();
                                    const name = emojiCell.modelData.n;
                                    const k = emojiCell.modelData.k || "";
                                    const sub = k ? k.split("|").join(", ") : "";
                                    emojiScope.hoveredText = q ? FzfLib.highlightHtml(name, q) : name;
                                    emojiScope.hoveredSubtitle = (q && sub) ? FzfLib.highlightHtml(sub, q) : sub;
                                    emojiScope.hoveredCell = emojiCell;
                                } else if (emojiScope.hoveredCell === emojiCell) {
                                    emojiScope.hoveredCell = null;
                                }
                            }
                        }

                        TapHandler {
                            id: emojiCellTap
                            onTapped: emojiScope.selectEmoji(emojiCell.modelData)
                        }
                    }
                }

                    // Shared draggable handle, sibling of the grid.
                    ScrollHandle {
                        target: emojiGrid
                        visible: emojiGrid.scrollable
                        anchors.right: parent.right
                        anchors.top: emojiGrid.top
                        anchors.bottom: emojiGrid.bottom
                    }
                }

                // Neo: full-bleed ink divider above the category strip (app-launcher style).
                // Tracks the strip's visibility; bleeds past the 12px panel margins.
                Rectangle {
                    visible: !Shape.usesBlur && emojiScope.searchText === "" && emojiScope.groups.length > 0
                    x: -Spacing.spacing12
                    width: parent.width + 2 * Spacing.spacing12
                    height: Shape.borderWidth
                    color: Colors.separatorColor
                }

                // Category strip: hidden during search (results span all groups).
                Row {
                    visible: emojiScope.searchText === "" && emojiScope.groups.length > 0
                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: emojiScope.groups
                        delegate: Item {
                            id: catCell
                            required property var modelData
                            required property int index
                            readonly property bool active: emojiScope.selectedGroup === index
                            width: parent.width / emojiScope.groups.length
                            height: emojiScope.categorySize

                            LauncherDelegateBg {
                                active: catCell.active || catHover.hovered
                                pressed: catTap.pressed
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.pixelSize: Typography.fontSize20
                                opacity: catCell.active ? 1.0 : 0.7
                            }

                            HoverHandler {
                                id: catHover
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: {
                                    if (hovered) {
                                        emojiScope.hoveredText = catCell.modelData.name || "";
                                        emojiScope.hoveredSubtitle = "";
                                        emojiScope.hoveredCell = catCell;
                                    } else if (emojiScope.hoveredCell === catCell) {
                                        emojiScope.hoveredCell = null;
                                    }
                                }
                            }
                            TapHandler {
                                id: catTap
                                onTapped: emojiScope.selectedGroup = catCell.index
                            }
                        }
                    }
                }
            }
        }
    }

    Tooltip {
        anchorItem: emojiScope.hoveredCell
        text: emojiScope.hoveredCell ? emojiScope.hoveredText : ""
        subtitle: emojiScope.hoveredCell ? emojiScope.hoveredSubtitle : ""
        textFormat: Text.StyledText
        screen: emojiWindow.screen
        recalcKey: emojiGrid.contentY
    }
}
