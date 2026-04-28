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
import "../lib/secret-mask.js" as SecretMask

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
    // Map clipId -> true for entries flagged as sensitive by the source-side
    // wrapper (KDE password-manager hint). Loaded from ~/.cache/cliphist/sensitive-ids.
    property var sensitiveIds: ({})

    onClipVisibleChanged: {
        if (clipVisible) {
            searchText = "";
            updateFilter();
            clipList.contentY = 0;
            clipList.currentIndex = 0;
            clipList.keyboardNav = false;
            // Background refresh: cached list shown immediately, new entries
            // replace once listProc finishes (usually <50ms).
            refresh();
        }
    }

    onSearchTextChanged: updateFilter()

    function refresh() {
        // Load sensitive-id sidecar first; on its completion, listProc runs.
        sensitiveProc.pending = ({});
        sensitiveProc.running = true;
    }

    function updateFilter() {
        const query = searchText.toLowerCase();
        if (query === "") {
            filteredEntries = allEntries;
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
        clipList.currentIndex = 0;
    }

    function selectEntry(entry) {
        clipVisible = false;
        decodeProc.entry = entry.raw;
        decodeProc.isImage = entry.isImage;
        decodeProc.running = true;
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
        id: sensitiveProc
        property var pending: ({})
        command: ["bash", "-c", "cat \"${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/sensitive-ids\" 2>/dev/null || true"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                const id = data.trim();
                if (id)
                    sensitiveProc.pending[id] = true;
            }
        }

        onExited: {
            clipScope.sensitiveIds = sensitiveProc.pending;
            listProc.pending = [];
            listProc.running = true;
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
                const masked = isImage
                    ? { display: rawDisplay, masked: false }
                    : SecretMask.maskEntry(rawDisplay, !!clipScope.sensitiveIds[clipId]);
                listProc.pending.push({
                    raw: data,
                    display: masked.display,
                    lower: masked.display.toLowerCase(),
                    isImage: isImage,
                    imagePath: isImage ? "/tmp/cliphist_preview_" + clipId + ".png" : "",
                    clipId: clipId,
                    masked: masked.masked
                });
            }
        }

        onExited: {
            clipScope.allEntries = listProc.pending;
            clipScope.updateFilter();
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
                    clipScope.selectEntry(clipScope.filteredEntries[clipList.currentIndex]);
            }
            onNavigated: (dx, dy) => {
                if (dy === 0)
                    return;
                clipList.keyboardNav = true;
                const next = clipList.currentIndex + dy;
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
                    readonly property bool active: clipList.currentIndex === index || clipDelegateHover.hovered
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

                    TintedIcon {
                        visible: !clipDelegate.modelData.isImage && clipDelegate.modelData.masked
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: Spacing.spacing12
                        }
                        source: "../icons/icons8-lock.svg"
                        size: Typography.fontSize16
                        color: Colors.textColorMuted
                    }

                    Text {
                        visible: !clipDelegate.modelData.isImage
                        anchors {
                            fill: parent
                            leftMargin: Spacing.spacing12
                            rightMargin: clipDelegate.modelData.masked ? Spacing.spacing12 + Typography.fontSize16 + Spacing.spacing8 : Spacing.spacing12
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
                        id: clipDelegateHover
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered && !clipList.keyboardNav)
                                clipList.currentIndex = clipDelegate.index;
                        }
                    }

                    TapHandler {
                        id: clipDelegateTap
                        onTapped: clipScope.selectEntry(clipDelegate.modelData)
                    }
                }
            }
        }
    }
}
