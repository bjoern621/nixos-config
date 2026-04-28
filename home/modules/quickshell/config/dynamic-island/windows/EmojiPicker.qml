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
import "../lib/emoji.js" as EmojiData

Scope {
    id: emojiScope

    readonly property int maxResults: 200
    readonly property int cellSize: 48
    readonly property int gridCols: 8
    readonly property int gridRows: 6

    property bool emojiVisible: false
    property string searchText: ""
    // Each item: { c, n, k, lower } where lower combines name + keywords
    property var indexedEmojis: []
    property var filteredEmojis: []

    onEmojiVisibleChanged: {
        if (emojiVisible) {
            searchText = "";
            updateFilter();
            emojiGrid.contentY = 0;
            emojiGrid.currentIndex = 0;
            emojiGrid.keyboardNav = false;
        }
    }

    onSearchTextChanged: updateFilter()

    Component.onCompleted: {
        const src = EmojiData.EMOJIS;
        const out = new Array(src.length);
        for (let i = 0; i < src.length; i++) {
            const e = src[i];
            const combined = e.k ? (e.n + " " + e.k) : e.n;
            out[i] = {
                c: e.c,
                n: e.n,
                lower: combined.toLowerCase()
            };
        }
        indexedEmojis = out;
        updateFilter();
    }

    function updateFilter() {
        const query = searchText.toLowerCase();
        if (query === "") {
            filteredEmojis = indexedEmojis.slice(0, maxResults);
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
        // Type the emoji directly: works in any app with focus, no clipboard
        // pollution. Small delay so the launcher window has fully unmapped and
        // keyboard focus has returned to the previously focused client.
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

        LauncherPanel {
            anchors.fill: parent
            searchText: emojiScope.searchText
            placeholder: "Emoji suchen..."
            panelWidth: emojiScope.cellSize * emojiScope.gridCols + 2 * Spacing.spacing12
            emptyVisible: emojiScope.filteredEmojis.length === 0 && emojiScope.searchText !== ""

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
                            if (hovered && !emojiGrid.keyboardNav)
                                emojiGrid.currentIndex = emojiCell.index;
                        }
                    }

                    TapHandler {
                        id: emojiCellTap
                        onTapped: emojiScope.selectEmoji(emojiCell.modelData)
                    }
                }
            }
        }
    }
}
