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
    // Loaded from $QUICKSHELL_EMOJI_DATA (built at home-manager rebuild).
    property var groups: []
    // Each indexed entry: { c, n, k, g, lower }
    property var indexedEmojis: []
    property var filteredEmojis: []

    // Tooltip target: set by hovered emoji/category delegate, cleared on exit.
    property Item hoveredCell: null
    property string hoveredText: ""
    property string hoveredSubtitle: ""

    onEmojiVisibleChanged: {
        if (emojiVisible) {
            searchText = "";
            updateFilter();
            emojiGrid.contentY = 0;
            emojiGrid.currentIndex = 0;
            emojiGrid.keyboardNav = false;
        } else {
            hoveredCell = null;
        }
    }

    onSearchTextChanged: {
        hoveredCell = null;
        updateFilter();
    }
    onSelectedGroupChanged: {
        hoveredCell = null;
        if (searchText === "")
            updateFilter();
        emojiGrid.contentY = 0;
        emojiGrid.currentIndex = 0;
    }

    FileView {
        id: emojiDataFile
        path: Quickshell.env("QUICKSHELL_EMOJI_DATA") || ""
        blockLoading: false
        onLoaded: emojiScope.parseData(emojiDataFile.text())
        onLoadFailed: error => console.warn("[EmojiPicker] failed to load:", error)
    }

    function parseData(text) {
        try {
            const data = JSON.parse(text);
            emojiScope.groups = data.groups || [];
            const src = data.emojis || [];
            const out = new Array(src.length);
            for (let i = 0; i < src.length; i++) {
                const e = src[i];
                const combined = e.k ? (e.n + " " + e.k) : e.n;
                out[i] = {
                    c: e.c,
                    n: e.n,
                    k: e.k || "",
                    g: e.g,
                    lower: combined.toLowerCase()
                };
            }
            emojiScope.indexedEmojis = out;
            emojiScope.updateFilter();
        } catch (err) {
            console.warn("[EmojiPicker] failed to parse:", err);
        }
    }

    function updateFilter() {
        const query = searchText.toLowerCase();
        if (query === "") {
            // No search: filter to selected group, keep CLDR order.
            const g = selectedGroup;
            filteredEmojis = indexedEmojis.filter(e => e.g === g);
            emojiGrid.currentIndex = 0;
            return;
        }
        const scored = [];
        for (let i = 0; i < indexedEmojis.length; i++) {
            const e = indexedEmojis[i];
            const s = FzfLib.scoreLower(e.n, e.lower, query);
            if (s > -Infinity)
                scored.push({
                    e,
                    score: s
                });
        }
        scored.sort((a, b) => b.score - a.score);
        const limit = Math.min(scored.length, maxResults);
        const out = new Array(limit);
        for (let i = 0; i < limit; i++)
            out[i] = scored[i].e;
        filteredEmojis = out;
        emojiGrid.currentIndex = 0;
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
        // sleep allows the emoji window to fully unmap and keyboard focus to
        // return to the previously focused client before wtype injects keys.
        command: ["bash", "-c", "sleep 0.05; wtype -- \"$EMOJI\""]
        environment: ({
                EMOJI: emoji
            })
        running: false
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

        Tooltip {
            id: emojiTooltip
            z: 100
            text: emojiScope.hoveredCell ? emojiScope.hoveredText : ""
            subtitle: emojiScope.hoveredCell ? emojiScope.hoveredSubtitle : ""
            x: {
                const cell = emojiScope.hoveredCell;
                if (!cell) return 0;
                const _ = emojiGrid.contentY;
                const p = cell.mapToItem(emojiTooltip.parent, cell.width / 2, 0);
                const min = Spacing.spacing8;
                const max = emojiTooltip.parent.width - emojiTooltip.width - Spacing.spacing8;
                return Math.max(min, Math.min(max, p.x - emojiTooltip.width / 2));
            }
            y: {
                const cell = emojiScope.hoveredCell;
                if (!cell) return 0;
                const _ = emojiGrid.contentY;
                const p = cell.mapToItem(emojiTooltip.parent, 0, 0);
                return p.y - emojiTooltip.height - Spacing.spacing4;
            }
        }

        LauncherPanel {
            id: panel
            anchors.fill: parent
            searchText: emojiScope.searchText
            placeholder: "Emoji suchen..."
            panelWidth: emojiScope.cellSize * emojiScope.gridCols + 2 * Spacing.spacing12
            emptyVisible: emojiScope.indexedEmojis.length > 0 && emojiScope.filteredEmojis.length === 0 && emojiScope.searchText !== ""

            onSearchEdited: text => emojiScope.searchText = text
            onEscaped: emojiScope.emojiVisible = false
            onAccepted: {
                if (emojiScope.filteredEmojis.length > 0)
                    emojiScope.selectEmoji(emojiScope.filteredEmojis[emojiGrid.currentIndex]);
            }
            onNavigated: (dx, dy) => {
                emojiGrid.keyboardNav = true;
                const cols = emojiScope.gridCols;
                const total = emojiScope.filteredEmojis.length;
                let next = emojiGrid.currentIndex + dx + dy * cols;
                if (next < 0)
                    next = 0;
                if (next >= total)
                    next = total - 1;
                emojiGrid.currentIndex = next;
            }
            onPageChange: dy => {
                emojiGrid.keyboardNav = true;
                const total = emojiScope.filteredEmojis.length;
                let next = emojiGrid.currentIndex + dy * emojiScope.gridCols * emojiScope.gridRows;
                if (next < 0)
                    next = 0;
                if (next >= total)
                    next = total - 1;
                emojiGrid.currentIndex = next;
            }

            Column {
                width: parent.width
                spacing: Spacing.spacing8

                LauncherGridView {
                    id: emojiGrid
                    width: parent.width
                    height: Math.min(contentHeight, emojiScope.cellSize * emojiScope.gridRows)
                    cellWidth: emojiScope.cellSize
                    cellHeight: emojiScope.cellSize
                    model: emojiScope.filteredEmojis

                    delegate: Item {
                        id: emojiCell
                        required property var modelData
                        required property int index
                        readonly property bool active: emojiGrid.currentIndex === index || emojiCellHover.hovered
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
                            id: emojiCellHover
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (hovered) {
                                    if (!emojiGrid.keyboardNav)
                                        emojiGrid.currentIndex = emojiCell.index;
                                    emojiScope.hoveredText = emojiCell.modelData.n;
                                    const k = emojiCell.modelData.k || "";
                                    emojiScope.hoveredSubtitle = k ? k.split("|").join(", ") : "";
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
}
