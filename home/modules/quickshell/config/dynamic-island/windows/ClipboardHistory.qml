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
    // Each entry: { raw, display, lower, isImage, imagePath, clipId }.
    // allEntries: full cliphist list, the filter source (plain array, no view
    // bound to it). Filtered view lives in clipModel.
    property var allEntries: []
    // Map clipId -> integer version (bumped each decode). Used to bust Image cache.
    property var imageVersions: ({})
    property var imageDecodeQueue: []

    onClipVisibleChanged: {
        if (clipVisible) {
            searchText = "";
            updateFilter();
            // cancelFlick() kills in-flight wheel momentum from the previous open.
            // positionViewAtBeginning() accounts for originY.
            // contentY = 0 leaves blank space above row 0 while a flick still animates.
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

    // resetIndex=false skips the selection write.
    // Background refreshes (listProc) must not clobber a hover-set selection.
    // User-driven calls (open, search) keep the default reset.
    function updateFilter(resetIndex = true) {
        const query = searchText.toLowerCase();
        let out;
        if (query === "") {
            out = allEntries;
        } else {
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
            out = new Array(limit);
            for (let i = 0; i < limit; i++)
                out[i] = scored[i].e;
        }
        // Full rebuild. A new query changes every row and resetting scroll to top
        // is intended; clear()+append is a model reset (contentY -> 0).
        // Deletes take the incremental path in deleteEntry instead.
        clipModel.clear();
        for (let i = 0; i < out.length; i++) {
            const e = out[i];
            clipModel.append({
                raw: e.raw,
                display: e.display,
                isImage: e.isImage,
                imagePath: e.imagePath,
                clipId: e.clipId
            });
        }
        // Keystroke-driven, so the keyboard takes the selection back from any hover.
        if (resetIndex)
            clipList.keyboardSelect(0);
    }

    function selectEntry(entry) {
        clipVisible = false;
        decodeProc.entry = entry.raw;
        decodeProc.isImage = entry.isImage;
        decodeProc.running = true;
    }

    function deleteEntry(entry) {
        // Fire-and-forget so rapid deletes don't queue on a Process object;
        // local model updated optimistically.
        Quickshell.execDetached(["bash", "-c", "printf '%s' \"$1\" | cliphist delete", "cliphist-delete", entry.raw]);
        allEntries = allEntries.filter(e => e.clipId !== entry.clipId);
        // Incremental remove, not a model reset: ListView shifts the rows below
        // up, holds contentY, destroys only the one delegate. No jump, no flicker.
        // Reassigning an array model would full-reset and snap contentY to 0.
        for (let i = 0; i < clipModel.count; i++) {
            if (clipModel.get(i).clipId === entry.clipId) {
                clipModel.remove(i);
                break;
            }
        }
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

    // Filtered view bound to the ListView. updateFilter rebuilds it; deleteEntry
    // removes one row (incremental), so a delete never resets the ListView.
    ListModel {
        id: clipModel
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

        // No anchors: the compositor centers a card-sized surface.
        implicitWidth: panel.surfaceWidth
        implicitHeight: panel.surfaceHeight

        exclusiveZone: 0
        focusable: true
        WlrLayershell.keyboardFocus: clipScope.clipVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        LauncherDismiss {
            hostWindow: clipWindow
            watch: panel
            active: clipScope.clipVisible
            onDismissed: clipScope.clipVisible = false
        }

        LauncherPanel {
            id: panel
            anchors.fill: parent
            searchText: clipScope.searchText
            placeholder: "Zwischenablage durchsuchen..."
            contentMaxHeight: clipScope.maxVisibleHeight
            emptyVisible: clipModel.count === 0 && clipScope.searchText !== ""

            onSearchEdited: text => clipScope.searchText = text
            onEscaped: clipScope.clipVisible = false
            onAccepted: {
                if (clipModel.count > 0)
                    clipScope.selectEntry(clipModel.get(clipList.effectiveIndex));
            }
            onNavigated: (dx, dy) => {
                if (dy !== 0)
                    clipList.keyboardSelect(clipList.effectiveIndex + dy);
            }

            LauncherListView {
                id: clipList
                // Reserve a gutter for the scroll handle only while it shows.
                width: parent.width - (scrollable ? Spacing.scrollGutter : 0)
                height: Math.min(contentHeight, clipScope.maxVisibleHeight)
                model: clipModel

                delegate: Item {
                    id: clipDelegate
                    required property int index
                    required property string raw
                    required property string display
                    required property bool isImage
                    required property string imagePath
                    required property string clipId
                    readonly property bool active: clipList.effectiveIndex === index
                    width: clipList.width
                    height: clipDelegate.isImage ? clipScope.imageRowHeight : clipScope.textRowHeight

                    LauncherDelegateBg {
                        active: clipDelegate.active
                        pressed: clipDelegateTap.pressed
                    }

                    Image {
                        visible: clipDelegate.isImage
                        anchors {
                            fill: parent
                            margins: Spacing.spacing4
                        }
                        source: {
                            if (!clipDelegate.isImage)
                                return "";
                            const v = clipScope.imageVersions[clipDelegate.clipId];
                            return v ? "file://" + clipDelegate.imagePath + "?v=" + v : "";
                        }
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        smooth: true
                        sourceSize.height: clipScope.imageRowHeight * 2
                    }

                    TintedIcon {
                        // Placeholder while image decode pending
                        id: clipPendingIcon
                        visible: clipDelegate.isImage && !clipScope.imageVersions[clipDelegate.clipId]
                        anchors.centerIn: parent
                        source: "../icons/icons8-spinner.svg"
                        size: Typography.fontSize24
                        color: Colors.textColorMuted

                        NumberAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                            running: clipPendingIcon.visible
                            easing.type: Easing.Linear
                        }
                    }

                    Text {
                        visible: !clipDelegate.isImage
                        anchors {
                            fill: parent
                            leftMargin: Spacing.spacing12
                            // Keeps elided text clear of the trash button.
                            rightMargin: Spacing.spacing8 + Spacing.spacing24 + Spacing.spacing8
                        }
                        text: clipDelegate.display
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
                        onTapped: clipScope.selectEntry({
                            raw: clipDelegate.raw,
                            isImage: clipDelegate.isImage
                        })
                    }

                    MiniIconButton {
                        id: trashBtn
                        anchors {
                            right: parent.right
                            rightMargin: Spacing.spacing8
                            top: parent.top
                            topMargin: Spacing.spacing8
                        }
                        source: "../icons/icons8-trash.svg"
                        // Reveal on row hover only.
                        opacity: rowHover.hovered ? 1.0 : 0.0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 80
                                easing.type: Easing.OutCubic
                            }
                        }

                        onClicked: clipScope.deleteEntry({
                            raw: clipDelegate.raw,
                            clipId: clipDelegate.clipId
                        })
                    }
                }
            }

            // Shared draggable handle, sibling of the list.
            ScrollHandle {
                target: clipList
                visible: clipList.scrollable
                anchors.right: parent.right
                anchors.top: clipList.top
                anchors.bottom: clipList.bottom
            }
        }
    }
}
