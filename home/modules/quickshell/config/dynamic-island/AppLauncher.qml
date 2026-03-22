import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import QtQuick.Controls

Scope {
    id: launcherScope

    property bool launcherVisible: false

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

    property var appIndexMap: ({})

    Process {
        id: fzfProc
        command: ["bash", "-c", "printf '%s\\n' \"$APP_LIST\" | fzf --filter=\"$QUERY\""]
        environment: ({ APP_LIST: "", QUERY: "" })
        running: false

        property var results: []

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (line.length > 0 && line in launcherScope.appIndexMap) {
                    fzfProc.results.push(launcherScope.appIndexMap[line])
                }
            }
        }

        onExited: (code, status) => {
            launcherWindow.filteredApps = fzfProc.results.slice(0, 50)
            resultsList.currentIndex = 0
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle() {
            if (!launcherScope.launcherVisible) {
                const s = launcherScope.focusedScreen()
                if (s) launcherWindow.screen = s
            }
            launcherScope.launcherVisible = !launcherScope.launcherVisible
        }
    }

    PanelWindow {
        id: launcherWindow

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        exclusiveZone: 0
        focusable: true
        WlrLayershell.keyboardFocus: launcherScope.launcherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        mask: Region {
            item: launcherScope.launcherVisible ? fullArea : emptyMask
        }

        Item {
            id: emptyMask
            width: 0
            height: 0
        }

        property var allApps: []
        property var filteredApps: []

        function rebuildAppList() {
            const apps = DesktopEntries.applications
            let list = []

            for (let i = 0; i < apps.values.length; i++) {
                const app = apps.values[i]
                if (app.noDisplay) continue
                list.push(app)
            }

            list.sort((a, b) => a.name.localeCompare(b.name))
            allApps = list
        }

        function updateFilter() {
            const query = searchInput.text.toLowerCase()
            if (query === "") {
                filteredApps = allApps.slice(0, 50)
                resultsList.currentIndex = 0
                return
            }

            let lines = []
            let indexMap = {}
            for (let i = 0; i < allApps.length; i++) {
                const name = allApps[i].name
                lines.push(name)
                indexMap[name] = allApps[i]
            }
            launcherScope.appIndexMap = indexMap

            fzfProc.results = []
            fzfProc.environment = { APP_LIST: lines.join("\n"), QUERY: query }
            fzfProc.running = true
        }

        function launchApp(app) {
            launcherScope.launcherVisible = false
            Quickshell.execDetached(["uwsm", "app", "--", app.id + ".desktop"])
        }

        Component.onCompleted: rebuildAppList()

        Connections {
            target: DesktopEntries
            function onApplicationsChanged() {
                launcherWindow.rebuildAppList()
                launcherWindow.updateFilter()
            }
        }

        Item {
            id: fullArea
            anchors.fill: parent

            // Click-to-dismiss (transparent, no dim)
            TapHandler {
                onTapped: launcherScope.launcherVisible = false
            }

            PopReveal {
                id: panelReveal
                width: 500
                height: panel.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                showing: launcherScope.launcherVisible
                showDuration: 120
                hideDuration: 120
                slideOffset: 0

                Rectangle {
                    id: panel
                    anchors.fill: parent
                    implicitHeight: contentColumn.implicitHeight + 2 * Spacing.spacing12

                    radius: Spacing.spacing12
                    color: Colors.pillBackground
                    border.width: 1
                    border.color: Colors.pillBorder
                }

                Column {
                    id: contentColumn
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
                        border.color: searchInput.activeFocus ? Colors.accentColor : Colors.pillBorder

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
                                id: searchInput
                                width: parent.width - Typography.fontSize14 - Spacing.spacing8 - 2 * Spacing.spacing12
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: Typography.fontFamily
                                font.pixelSize: Typography.fontSize14
                                font.weight: Font.Bold
                                color: Colors.textColor
                                clip: true
                                selectByMouse: true
                                onActiveFocusChanged: if (!activeFocus && launcherScope.launcherVisible) launcherScope.launcherVisible = false

                                Text {
                                    anchors.fill: parent
                                    text: "Suchen..."
                                    font: parent.font
                                    color: Colors.textColorMuted
                                    visible: !parent.text && !parent.activeFocus
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onTextChanged: launcherWindow.updateFilter()

                                Keys.onEscapePressed: launcherScope.launcherVisible = false
                                Keys.onReturnPressed: {
                                    if (launcherWindow.filteredApps.length > 0) {
                                        launcherWindow.launchApp(launcherWindow.filteredApps[resultsList.currentIndex])
                                    }
                                }
                                Keys.onDownPressed: {
                                    if (resultsList.currentIndex < launcherWindow.filteredApps.length - 1) {
                                        resultsList.currentIndex++
                                    }
                                }
                                Keys.onUpPressed: {
                                    if (resultsList.currentIndex > 0) {
                                        resultsList.currentIndex--
                                    }
                                }
                            }
                        }
                    }

                    ListView {
                        id: resultsList
                        width: parent.width
                        height: Math.min(contentHeight, 8 * 44)
                        clip: true
                        currentIndex: 0
                        model: launcherWindow.filteredApps
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: resultsList.contentHeight > resultsList.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
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
                            width: resultsList.width
                            height: 44

                            Rectangle {
                                anchors.fill: parent
                                radius: Spacing.spacing8
                                color: delegateTap.pressed ? Colors.hoverItemPressed
                                     : resultsList.currentIndex === index || delegateHover.hovered ? Colors.hoverItemHovered
                                     : "transparent"
                                border.color: resultsList.currentIndex === index || delegateHover.hovered || delegateTap.pressed ? Colors.pillBorder : "transparent"
                            }

                            Row {
                                anchors {
                                    fill: parent
                                    leftMargin: Spacing.spacing12
                                    rightMargin: Spacing.spacing12
                                }
                                spacing: Spacing.spacing12

                                Image {
                                    id: appIcon
                                    width: Typography.fontSize24
                                    height: Typography.fontSize24
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: modelData.icon ? ("image://icon/" + modelData.icon) : ""
                                    sourceSize: Qt.size(Typography.fontSize24, Typography.fontSize24)
                                }

                                Text {
                                    text: "\uf009"
                                    font.family: Typography.iconFontFamily
                                    font.pixelSize: Typography.fontSize16
                                    color: Colors.textColorMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Typography.fontSize24
                                    horizontalAlignment: Text.AlignHCenter
                                    visible: appIcon.status !== Image.Ready
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - Typography.fontSize24 - Spacing.spacing12 - 2 * Spacing.spacing12
                                    spacing: Spacing.spacing2

                                    Text {
                                        text: modelData.name
                                        font.family: Typography.fontFamily
                                        font.pixelSize: Typography.fontSize14
                                        font.weight: Font.Bold
                                        color: Colors.textColor
                                        width: parent.width
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: modelData.comment || ""
                                        font.family: Typography.fontFamily
                                        font.pixelSize: Typography.fontSize12
                                        font.weight: Font.Normal
                                        color: Colors.textColorMuted
                                        width: parent.width
                                        elide: Text.ElideRight
                                        visible: text !== ""
                                    }
                                }
                            }

                            HoverHandler {
                                id: delegateHover
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: {
                                    if (hovered) resultsList.currentIndex = index
                                }
                            }

                            TapHandler {
                                id: delegateTap
                                onTapped: launcherWindow.launchApp(modelData)
                            }
                        }
                    }

                    Text {
                        visible: launcherWindow.filteredApps.length === 0 && searchInput.text !== ""
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
            onTriggered: searchInput.forceActiveFocus()
        }

        Connections {
            target: launcherScope
            function onLauncherVisibleChanged() {
                if (launcherScope.launcherVisible) {
                    searchInput.text = ""
                    launcherWindow.updateFilter()
                    focusTimer.restart()
                }
            }
        }
    }
}
