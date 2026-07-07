pragma ComponentBehavior: Bound

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
    id: clipScope

    readonly property int maxResults: 100
    readonly property int textRowHeight: 40
    readonly property int imageRowHeight: 180
    readonly property int maxVisibleHeight: 8 * 40

    property bool clipVisible: false
    property string searchText: ""
    // Each entry: { raw, display, lower, isImage, imagePath, clipId }
    property var allEntries: []
    property var filteredEntries: []
    // Map clipId -> integer version (bumped each decode). Used to bust Image cache.
    property var imageVersions: ({})
    property var imageDecodeQueue: []

    onClipVisibleChanged: {
        if (clipVisible) {
            searchText = "";
            updateFilter();
            // cancelFlick() kills any in-flight wheel-flick momentum from the previous open; positionViewAtBeginning() handles originY correctly (setting contentY = 0 directly leaves blank space above row 0 if a flick was still animating).
            clipList.cancelFlick();
            clipList.positionViewAtBeginning();
            clipList.reset();
            // Background refresh: cached list shown immediately, new entries
            // replace once listProc finishes (usually <50ms).
            refresh();
        }
    }

    onSearchTextChanged: updateFilter()

    function refresh() {
        listProc.pending = [];
        listProc.running = true;
    }

    // resetIndex=false skips the `currentIndex = 0` write so background refreshes (listProc) and deletes don't clobber a hover-set selection from MouseArea. User-driven calls (open, search) keep the default reset.
    function updateFilter(resetIndex = true) {
        const query = searchText.toLowerCase();
        if (query === "") {
            filteredEntries = allEntries;
            if (resetIndex)
                clipList.currentIndex = 0;
            return;
        }
        const scored = [];
        for (let i = 0; i < allEntries.length; i++) {
            const e = allEntries[i];
            const s = FzfLib.scoreLower(e.display, e.lower, query);
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
        filteredEntries = out;
        if (resetIndex)
            clipList.currentIndex = 0;
    }

    function selectEntry(entry) {
        clipVisible = false;
        decodeProc.entry = entry.raw;
        decodeProc.isImage = entry.isImage;
        decodeProc.running = true;
    }

    function deleteEntry(entry) {
        // Fire-and-forget so rapid deletes don't queue on a Process object;
        // the local model is updated optimistically.
        Quickshell.execDetached(["bash", "-c", "printf '%s' \"$1\" | cliphist delete", "cliphist-delete", entry.raw]);
        allEntries = allEntries.filter(e => e.clipId !== entry.clipId);
        updateFilter(false);
    }

    function decodeNextImage() {
        if (imageDecodeQueue.length === 0)
            return;
        const entry = imageDecodeQueue[0];
        imageDecodeQueue = imageDecodeQueue.slice(1);
        imageDecodeProc.clipId = entry.clipId;
        imageDecodeProc.environment = {
            CLIP_ENTRY: entry.raw,
            OUT_PATH: entry.imagePath
        };
        imageDecodeProc.running = true;
    }

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor;
        return mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? null) : null;
    }

    function toggle() {
        if (!clipVisible) {
            const s = focusedScreen();
            if (s)
                clipWindow.screen = s;
        }
        clipVisible = !clipVisible;
    }

    Component.onCompleted: refresh()

    GlobalShortcut {
        appid: "quickshell"
        name: "clipboard"
        description: "Toggle the clipboard history"
        onPressed: clipScope.toggle()
    }

    IpcHandler {
        target: "clipboard"
        function toggle() {
            clipScope.toggle();
        }
    }

    Process {
        id: listProc
        property var pending: []
        command: ["cliphist", "list"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                const tabIdx = data.indexOf('\t');
                if (tabIdx < 0)
                    return;
                const rawDisplay = data.substring(tabIdx + 1).trim();
                if (rawDisplay.length === 0)
                    return;
                const isImage = rawDisplay.startsWith("[[ binary data");
                const clipId = data.substring(0, tabIdx).trim();
                listProc.pending.push({
                    raw: data,
                    display: rawDisplay,
                    lower: rawDisplay.toLowerCase(),
                    isImage: isImage,
                    imagePath: isImage ? "/tmp/cliphist_preview_" + clipId + ".png" : "",
                    clipId: clipId
                });
            }
        }

        onExited: {
            clipScope.allEntries = listProc.pending;
            clipScope.updateFilter(false);
            // Queue images that haven't been decoded this session.
            const versions = clipScope.imageVersions;
            const queue = listProc.pending.filter(e => e.isImage && !(e.clipId in versions));
            clipScope.imageDecodeQueue = queue;
            clipScope.decodeNextImage();
        }
    }

    Process {
        id: imageDecodeProc
        property string clipId: ""
        command: ["bash", "-c", "printf '%s' \"$CLIP_ENTRY\" | cliphist decode > \"$OUT_PATH\""]
        environment: ({
                CLIP_ENTRY: "",
                OUT_PATH: ""
            })
        running: false

        onExited: code => {
            if (code === 0 && imageDecodeProc.clipId) {
                const v = clipScope.imageVersions;
                clipScope.imageVersions = Object.assign({}, v, {
                    [imageDecodeProc.clipId]: (v[imageDecodeProc.clipId] || 0) + 1
                });
            }
            clipScope.decodeNextImage();
        }
    }

    Process {
        id: decodeProc
        property string entry: ""
        property bool isImage: false
        command: ["bash", "-c", isImage ? "printf '%s' \"$CLIP_ENTRY\" | cliphist decode | wl-copy --type image/png" : "printf '%s' \"$CLIP_ENTRY\" | cliphist decode | wl-copy"]
        environment: ({
                CLIP_ENTRY: entry
            })
        running: false

        onExited: {
            Quickshell.execDetached(["wtype", "-M", "ctrl", "-M", "shift", "v", "-m", "shift", "-m", "ctrl"]);
        }
    }

    PanelWindow {
        id: clipWindow
        visible: clipScope.clipVisible
        WlrLayershell.namespace: "quickshell-clipboard"

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        exclusiveZone: 0
        focusable: true
        WlrLayershell.keyboardFocus: clipScope.clipVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        AutoCloseOnFocusLoss {
            watch: panel
            armed: clipScope.clipVisible
            onLost: clipScope.clipVisible = false
        }

        LauncherPanel {
            id: panel
            anchors.fill: parent
            searchText: clipScope.searchText
            placeholder: "Zwischenablage durchsuchen..."
            emptyVisible: clipScope.filteredEntries.length === 0 && clipScope.searchText !== ""

            onSearchEdited: text => clipScope.searchText = text
            onEscaped: clipScope.clipVisible = false
            onAccepted: {
                if (clipScope.filteredEntries.length > 0)
                    clipScope.selectEntry(clipScope.filteredEntries[clipList.effectiveIndex]);
            }
            onNavigated: (dx, dy) => {
                if (dy === 0)
                    return;
                const next = clipList.effectiveIndex + dy;
                clipList.keyboardNav = true;
                if (next >= 0 && next < clipScope.filteredEntries.length)
                    clipList.currentIndex = next;
            }

            LauncherListView {
                id: clipList
                width: parent.width
                height: Math.min(contentHeight, clipScope.maxVisibleHeight)
                model: clipScope.filteredEntries

                delegate: Item {
                    id: clipDelegate
                    required property var modelData
                    required property int index
                    readonly property bool active: clipList.effectiveIndex === index
                    width: clipList.width
                    height: modelData.isImage ? clipScope.imageRowHeight : clipScope.textRowHeight

                    LauncherDelegateBg {
                        active: clipDelegate.active
                        pressed: clipDelegateTap.pressed
                    }

                    Image {
                        visible: modelData.isImage
                        anchors {
                            fill: parent
                            margins: Spacing.spacing4
                        }
                        source: {
                            if (!modelData.isImage)
                                return "";
                            const v = clipScope.imageVersions[modelData.clipId];
                            return v ? "file://" + modelData.imagePath + "?v=" + v : "";
                        }
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        smooth: true
                        sourceSize.height: clipScope.imageRowHeight * 2
                    }

                    TintedIcon {
                        // Placeholder while image decode pending
                        visible: modelData.isImage && !clipScope.imageVersions[modelData.clipId]
                        anchors.centerIn: parent
                        source: "../icons/icons8-menu.svg"
                        size: Typography.fontSize24
                        color: Colors.textColorMuted
                    }

                    Text {
                        visible: !clipDelegate.modelData.isImage
                        anchors {
                            fill: parent
                            leftMargin: Spacing.spacing12
                            // Keeps elided text clear of the trash button.
                            rightMargin: Spacing.spacing8 + Spacing.spacing24 + Spacing.spacing8
                        }
                        text: clipDelegate.modelData.display
                        font.family: Typography.fontFamily
                        font.pixelSize: Typography.fontSize14
                        font.weight: Font.Normal
                        color: Colors.textColor
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    HoverHandler {
                        id: rowHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: clipDelegateTap
                        onTapped: clipScope.selectEntry(clipDelegate.modelData)
                    }

                    Rectangle {
                        id: trashBtn
                        anchors {
                            right: parent.right
                            rightMargin: Spacing.spacing8
                            top: parent.top
                            topMargin: Spacing.spacing8
                        }
                        width: Spacing.spacing24
                        height: Spacing.spacing24
                        radius: height / 2
                        color: trashTap.pressed ? Colors.hoverItemPressed : trashHover.hovered ? Colors.hoverItemHovered : "transparent"
                        border.color: trashHover.hovered ? Colors.pillBorder : "transparent"
                        opacity: rowHover.hovered ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 80
                                easing.type: Easing.OutCubic
                            }
                        }

                        scale: trashTap.pressed ? 0.85 : 1.0
                        SquishBehavior on scale {}

                        HoverHandler {
                            id: trashHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            id: trashTap
                            // Exclusive grab on press so the row's select TapHandler doesn't also fire.
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: clipScope.deleteEntry(clipDelegate.modelData)
                        }

                        TintedIcon {
                            anchors.centerIn: parent
                            size: Spacing.spacing12
                            source: "../icons/icons8-trash.svg"
                            color: Colors.textColorMuted
                        }
                    }
                }
            }
        }
    }
}
