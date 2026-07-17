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
        updateFilter();
    }
    onSelectedGroupChanged: {
        hoveredCell = null;
        if (searchText === "")
            updateFilter();
        emojiScope.rewindGrid();
        emojiGrid.currentIndex = 0;
        emojiGrid.hoveredIndex = -1;
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
            // Match against combined name+keywords (e.lower); pass it as `text`
            // too because scoreLower's outer loop bounds by text.length.
            const s = FzfLib.scoreLower(e.lower, e.lower, query);
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
            panelWidth: emojiScope.cellSize * emojiScope.gridCols + 2 * Spacing.spacing12
            emptyVisible: emojiScope.indexedEmojis.length > 0 && emojiScope.filteredEmojis.length === 0 && emojiScope.searchText !== ""

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
