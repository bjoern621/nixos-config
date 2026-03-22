import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick

Scope {
    id: clipScope

    property bool clipVisible: false
    property var allEntries: []
    property var filteredEntries: []

    function fuzzyScore(text, query) {
        text = text.toLowerCase()
        let score = 0
        let qi = 0
        let lastMatchIdx = -1
        for (let ti = 0; ti < text.length && qi < query.length; ti++) {
            if (text[ti] === query[qi]) {
                score += (lastMatchIdx === ti - 1) ? 10 : 1
                if (ti === 0 || text[ti - 1] === ' ' || text[ti - 1] === '-') score += 5
                lastMatchIdx = ti
                qi++
            }
        }
        if (qi < query.length) return -1
        if (text.startsWith(query)) score += 20
        return score
    }

    function selectEntry(entry) {
        clipScope.clipVisible = false
        decodeProc.entry = entry.raw
        decodeProc.running = true
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
                        clipScope.allEntries = [...clipScope.allEntries, { raw: data, display: display }]
                    }
                }
            }
        }

        onExited: (code, status) => {
            clipScope.filteredEntries = clipScope.allEntries.slice(0, 50)
        }
    }

    // Decode + copy selected entry
    Process {
        id: decodeProc
        property string entry: ""
        command: ["bash", "-c", "printf '%s' \"$CLIP_ENTRY\" | cliphist decode | wl-copy"]
        environment: ({ CLIP_ENTRY: entry })
        running: false

        onExited: (code, status) => {
            Quickshell.execDetached(["wtype", "-M", "ctrl", "-M", "shift", "v", "-m", "shift", "-m", "ctrl"])
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle() {
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

                                onTextChanged: {
                                    const query = text.toLowerCase()
                                    if (query === "") {
                                        clipScope.filteredEntries = clipScope.allEntries.slice(0, 50)
                                    } else {
                                        let scored = []
                                        for (let i = 0; i < clipScope.allEntries.length; i++) {
                                            const entry = clipScope.allEntries[i]
                                            const s = clipScope.fuzzyScore(entry.display, query)
                                            if (s > 0) scored.push({ entry: entry, score: s })
                                        }
                                        scored.sort((a, b) => b.score - a.score)
                                        let results = []
                                        for (let i = 0; i < scored.length && i < 50; i++) results.push(scored[i].entry)
                                        clipScope.filteredEntries = results
                                    }
                                    clipList.currentIndex = 0
                                }

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

                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: clipList.width
                            height: 40

                            Rectangle {
                                anchors.fill: parent
                                radius: Spacing.spacing8
                                color: clipDelegateTap.pressed ? Colors.hoverItemPressed
                                     : clipList.currentIndex === index || clipDelegateHover.hovered ? Colors.hoverItemHovered
                                     : "transparent"
                                border.color: clipList.currentIndex === index || clipDelegateHover.hovered || clipDelegateTap.pressed ? Colors.pillBorder : "transparent"
                            }

                            Text {
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
                    listProc.running = true
                    clipList.currentIndex = 0
                    focusTimer.restart()
                }
            }
        }
    }
}
