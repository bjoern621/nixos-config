import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import QtQuick.Controls

Scope {
    id: clipScope

    property bool clipVisible: false

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor
        if (mon) {
            const screens = Quickshell.screens
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === mon.name)
                    return screens[i]
            }
        }
        return null
    }

    property var allEntries: []
    property var filteredEntries: []
    property var imageDecodeQueue: []
    property int decodedCount: 0

    Process {
        id: fzfProc
        command: ["bash", "-c", "printf '%s\\n' \"$CLIP_LIST\" | fzf --filter=\"$QUERY\""]
        environment: ({ CLIP_LIST: "", QUERY: "" })
        running: false

        property var results: []

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (line.length > 0 && line in clipScope.entryIndexMap) {
                    fzfProc.results.push(clipScope.entryIndexMap[line])
                }
            }
        }

        onExited: (code, status) => {
            clipScope.filteredEntries = fzfProc.results
            clipList.currentIndex = 0
        }
    }

    property var entryIndexMap: ({})

    function updateFilter() {
        const query = clipSearch.text.toLowerCase()
        if (query === "") {
            filteredEntries = allEntries
            clipList.currentIndex = 0
            return
        }

        let lines = []
        let indexMap = {}
        for (let i = 0; i < allEntries.length; i++) {
            const key = i + "\t" + allEntries[i].display
            lines.push(key)
            indexMap[key] = allEntries[i]
        }
        entryIndexMap = indexMap

        fzfProc.results = []
        fzfProc.environment = { CLIP_LIST: lines.join("\n"), QUERY: query }
        fzfProc.running = true
    }

    function selectEntry(entry) {
        clipScope.clipVisible = false
        decodeProc.entry = entry.raw
        decodeProc.isImage = entry.isImage
        decodeProc.running = true
    }

    function decodeNextImage() {
        if (imageDecodeQueue.length === 0) return
        const entry = imageDecodeQueue.shift()
        imageDecodeProc.entry = entry
        imageDecodeProc.environment = {
            CLIP_ENTRY: entry.raw,
            OUT_PATH: entry.imagePath
        }
        imageDecodeProc.running = true
    }

    Process {
        id: imageDecodeProc
        property var entry: null
        command: ["bash", "-c", "printf '%s' \"$CLIP_ENTRY\" | cliphist decode > \"$OUT_PATH\""]
        environment: ({ CLIP_ENTRY: "", OUT_PATH: "" })
        running: false

        onExited: (code, status) => {
            if (code === 0 && imageDecodeProc.entry) {
                // Bump decodedCount to trigger image reloads
                clipScope.decodedCount++
            }
            clipScope.decodeNextImage()
        }
    }

    // Fetch clipboard history
    Process {
        id: listProc
        command: ["cliphist", "list"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                const tabIdx = data.indexOf('\t')
                if (tabIdx >= 0) {
                    const display = data.substring(tabIdx + 1).trim()
                    if (display.length > 0) {
                        const isImage = display.startsWith("[[ binary data")
                        const entry = { raw: data, display: display, isImage: isImage, imagePath: "" }
                        if (isImage) {
                            const clipId = data.substring(0, tabIdx).trim()
                            entry.imagePath = "/tmp/cliphist_preview_" + clipId + ".png"
                        }
                        clipScope.allEntries = [...clipScope.allEntries, entry]
                    }
                }
            }
        }

        onExited: (code, status) => {
            clipScope.filteredEntries = clipScope.allEntries
            // Queue image entries for decoding
            let queue = []
            for (let i = 0; i < clipScope.allEntries.length; i++) {
                if (clipScope.allEntries[i].isImage) {
                    queue.push(clipScope.allEntries[i])
                }
            }
            clipScope.imageDecodeQueue = queue
            clipScope.decodeNextImage()
        }
    }

    // Decode + copy selected entry
    Process {
        id: decodeProc
        property string entry: ""
        property bool isImage: false
        command: ["bash", "-c", isImage
            ? "printf '%s' \"$CLIP_ENTRY\" | cliphist decode | wl-copy --type image/png"
            : "printf '%s' \"$CLIP_ENTRY\" | cliphist decode | wl-copy"
        ]
        environment: ({ CLIP_ENTRY: entry })
        running: false

        onExited: (code, status) => {
            Quickshell.execDetached(["wtype", "-M", "ctrl", "-M", "shift", "v", "-m", "shift", "-m", "ctrl"])
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle() {
            if (!clipScope.clipVisible) {
                const s = clipScope.focusedScreen()
                if (s) clipWindow.screen = s
            }
            clipScope.clipVisible = !clipScope.clipVisible
        }
    }

    PanelWindow {
        id: clipWindow

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

        mask: Region {
            item: clipScope.clipVisible ? clipFullArea : clipEmptyMask
        }

        Item {
            id: clipEmptyMask
            width: 0
            height: 0
        }

        Item {
            id: clipFullArea
            anchors.fill: parent

            TapHandler {
                onTapped: clipScope.clipVisible = false
            }

            Rectangle {
                id: clipPanel
                width: 500
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                height: clipContent.implicitHeight + 2 * Spacing.spacing12

                radius: Spacing.spacing12
                color: Colors.pillBackground
                border.width: 1
                border.color: Colors.pillBorder

                opacity: clipScope.clipVisible ? 1 : 0
                scale: clipScope.clipVisible ? 1.0 : 0.96
                transformOrigin: Item.Top

                Behavior on opacity {
                    NumberAnimation { duration: 120; easing.type: clipScope.clipVisible ? Easing.OutCubic : Easing.InCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 120; easing.type: clipScope.clipVisible ? Easing.OutCubic : Easing.InCubic }
                }

                Column {
                    id: clipContent
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
                        border.color: clipSearch.activeFocus ? Colors.accentColor : Colors.pillBorder

                        Row {
                            anchors {
                                fill: parent
                                leftMargin: Spacing.spacing12
                                rightMargin: Spacing.spacing12
                            }
                            spacing: Spacing.spacing8

                            Text {
                                text: "\uf002"
                                font.family: Typography.iconFontFamily
                                font.pixelSize: Typography.fontSize14
                                color: Colors.textColorMuted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            TextInput {
                                id: clipSearch
                                width: parent.width - Typography.fontSize14 - Spacing.spacing8 - 2 * Spacing.spacing12
                                anchors.verticalCenter: parent.verticalCenter
                                onActiveFocusChanged: if (!activeFocus && clipScope.clipVisible) clipScope.clipVisible = false
                                font.family: Typography.fontFamily
                                font.pixelSize: Typography.fontSize14
                                font.weight: Font.Bold
                                color: Colors.textColor
                                clip: true
                                selectByMouse: true

                                Text {
                                    anchors.fill: parent
                                    text: "Zwischenablage durchsuchen..."
                                    font: parent.font
                                    color: Colors.textColorMuted
                                    visible: !parent.text && !parent.activeFocus
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onTextChanged: clipScope.updateFilter()

                                Keys.onEscapePressed: clipScope.clipVisible = false
                                Keys.onReturnPressed: {
                                    if (clipScope.filteredEntries.length > 0) {
                                        clipScope.selectEntry(clipScope.filteredEntries[clipList.currentIndex])
                                    }
                                }
                                Keys.onDownPressed: {
                                    if (clipList.currentIndex < clipScope.filteredEntries.length - 1) {
                                        clipList.currentIndex++
                                    }
                                }
                                Keys.onUpPressed: {
                                    if (clipList.currentIndex > 0) {
                                        clipList.currentIndex--
                                    }
                                }
                            }
                        }
                    }

                    ListView {
                        id: clipList
                        width: parent.width
                        height: Math.min(contentHeight, 8 * 40)
                        clip: true
                        currentIndex: 0
                        model: clipScope.filteredEntries
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: clipList.contentHeight > clipList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                            contentItem: Rectangle {
                                implicitWidth: 4
                                radius: width / 2
                                color: Colors.textColorMuted
                                opacity: parent.active ? 0.6 : 0.3
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }
                        }

                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: clipList.width
                            height: modelData.isImage ? 100 : 40

                            Rectangle {
                                anchors.fill: parent
                                radius: Spacing.spacing8
                                color: clipDelegateTap.pressed ? Colors.hoverItemPressed
                                     : clipList.currentIndex === index || clipDelegateHover.hovered ? Colors.hoverItemHovered
                                     : "transparent"
                                border.color: clipList.currentIndex === index || clipDelegateHover.hovered || clipDelegateTap.pressed ? Colors.pillBorder : "transparent"
                            }

                            Image {
                                visible: modelData.isImage
                                anchors {
                                    fill: parent
                                    margins: Spacing.spacing4
                                }
                                // Use decodedCount to refresh after decode completes
                                source: modelData.isImage && clipScope.decodedCount >= 0 ? "file://" + modelData.imagePath : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                            }

                            Text {
                                visible: !modelData.isImage
                                anchors {
                                    fill: parent
                                    leftMargin: Spacing.spacing12
                                    rightMargin: Spacing.spacing12
                                }
                                text: modelData.display
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
                                    if (hovered) clipList.currentIndex = index
                                }
                            }

                            TapHandler {
                                id: clipDelegateTap
                                onTapped: clipScope.selectEntry(modelData)
                            }
                        }
                    }

                    Text {
                        visible: clipScope.filteredEntries.length === 0 && clipSearch.text !== ""
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

        Timer {
            id: focusTimer
            interval: 50
            onTriggered: clipSearch.forceActiveFocus()
        }

        Connections {
            target: clipScope
            function onClipVisibleChanged() {
                if (clipScope.clipVisible) {
                    clipSearch.text = ""
                    clipScope.allEntries = []
                    clipScope.filteredEntries = []
                    clipScope.imageDecodeQueue = []
                    clipScope.decodedCount = 0
                    listProc.running = true
                    clipList.currentIndex = 0
                    focusTimer.restart()
                }
            }
        }
    }
}
