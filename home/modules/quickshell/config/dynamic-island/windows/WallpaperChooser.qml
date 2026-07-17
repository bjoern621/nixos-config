import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import "../"

Scope {
    id: chooserScope

    property bool chooserVisible: false
    property int previousWorkspaceId: -1
    property url originalWallpaper: ""
    property int currentIndex: 0
    property var wallpaperList: []

    readonly property int cardWidth: 200
    readonly property int cardHeight: 130
    readonly property int cardSpacing: Spacing.spacing12

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor;
        if (mon) {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === mon.name)
                    return screens[i];
            }
        }
        return null;
    }

    function open() {
        // Save current state
        const mon = Hyprland.focusedMonitor;
        if (!mon)
            return;
        previousWorkspaceId = mon.activeWorkspace.id;
        originalWallpaper = Globals.wallpaperPath;

        // Find current wallpaper index
        const currentPath = Globals.wallpaperPath.toString().replace("file://", "");
        for (let i = 0; i < wallpaperList.length; i++) {
            if (wallpaperList[i] === currentPath) {
                currentIndex = i;
                break;
            }
        }

        // Switch to empty workspace to hide windows
        workspaceProc.command = ["hyprctl", "dispatch", "workspace", "name:wallpaper"];
        workspaceProc.running = true;

        // Show on focused screen
        const s = focusedScreen();
        if (s)
            chooserWindow.screen = s;
        chooserVisible = true;
    }

    function apply() {
        const path = wallpaperList[currentIndex];

        WallpaperPersist.save(path);

        // Wallpaper is already showing via hyprpaper preview, just close.
        close();
    }

    function cancel() {
        // restoreWallpaper() already resets Globals.wallpaperPath.
        restoreWallpaper();
        close();
    }

    function close() {
        chooserScope.chooserVisible = false;
        // Switch back to previous workspace
        if (chooserScope.previousWorkspaceId > 0) {
            workspaceProc.command = ["hyprctl", "dispatch", "workspace", String(previousWorkspaceId)];
            workspaceProc.running = true;
        }
    }

    function navigateLeft() {
        if (chooserScope.currentIndex > 0)
            previewCard(chooserScope.currentIndex - 1);
    }

    function navigateRight() {
        if (chooserScope.currentIndex < chooserScope.wallpaperList.length - 1)
            previewCard(chooserScope.currentIndex + 1);
    }

    function previewCard(idx) {
        if (idx < 0 || idx >= chooserScope.wallpaperList.length)
            return;
        chooserScope.currentIndex = idx;

        const path = chooserScope.wallpaperList[idx];

        // Setting the global triggers WallpaperBackend to apply it
        Globals.wallpaperPath = "file://" + path;
    }

    function restoreWallpaper() {
        // Restoring the global triggers WallpaperBackend to apply it
        Globals.wallpaperPath = originalWallpaper;
    }

    // --- Processes ---

    Process {
        id: listProc
        command: ["bash", "-c", "ls -1 ~/.local/share/wallpapers/*.jpg ~/.local/share/wallpapers/*.png 2>/dev/null | sort"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line.length > 0)
                    chooserScope.wallpaperList.push(line);
            }
        }
        onExited: chooserScope.wallpaperListChanged()
    }

    Process {
        id: workspaceProc
    }

    Process {
        id: openFolderProc
        // bash -c expands ~.
        // exec'd directly, xdg-open gets it literally and opens nothing.
        command: ["bash", "-c", "xdg-open ~/.local/share/wallpapers"]
    }

    // Load wallpaper list on startup
    Component.onCompleted: listProc.running = true

    IpcHandler {
        target: "wallpaper"

        function toggle() {
            if (!chooserScope.chooserVisible)
                chooserScope.open();
            else
                chooserScope.cancel();
        }
    }

    PanelWindow {
        id: chooserWindow
        visible: chooserScope.chooserVisible || !hideComplete
        property bool hideComplete: true

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        exclusiveZone: 0
        focusable: true
        WlrLayershell.keyboardFocus: chooserScope.chooserVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-noblur"
        color: "transparent"

        // Use cancel() so the workspace switch is properly reverted.
        AutoCloseOnFocusLoss {
            watch: fullArea
            armed: chooserScope.chooserVisible
            onLost: chooserScope.cancel()
        }

        mask: Region {
            item: chooserScope.chooserVisible ? fullArea : emptyMask
        }

        Item {
            id: emptyMask
            width: 0
            height: 0
        }

        Item {
            id: fullArea
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: chooserScope.cancel()
            Keys.onReturnPressed: chooserScope.apply()
            Keys.onLeftPressed: chooserScope.navigateLeft()
            Keys.onRightPressed: chooserScope.navigateRight()

            // Absorb background clicks so they don't pass through the layer surface
            MouseArea {
                anchors.fill: parent
            }

            // Bottom-anchored carousel
            PopReveal {
                id: carouselReveal
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Spacing.spacing40
                anchors.horizontalCenter: parent.horizontalCenter
                width: carouselWrapper.width
                height: carouselWrapper.height
                showing: chooserScope.chooserVisible
                transformOriginValue: Item.Bottom
                slideOffset: -Spacing.spacing16

                Item {
                    id: carouselWrapper
                    width: carouselContent.width
                    height: carouselContent.height

                    // Absorb clicks so they don't reach the background dismiss TapHandler
                    MouseArea {
                        anchors.fill: parent
                    }

                    Column {
                        id: carouselContent
                        spacing: Spacing.spacing16

                        // Carousel row
                        Item {
                            id: carouselViewport
                            width: Math.min(fullArea.width - 2 * Spacing.spacing40, (chooserScope.cardWidth + chooserScope.cardSpacing) * 7)
                            height: chooserScope.cardHeight + 60 // extra space for arc drop + label
                            clip: true

                            Item {
                                id: carouselRow
                                // Center the current card in the viewport
                                x: (carouselViewport.width / 2) - (chooserScope.currentIndex * (chooserScope.cardWidth + chooserScope.cardSpacing)) - (chooserScope.cardWidth / 2)
                                y: 0
                                width: chooserScope.wallpaperList.length * (chooserScope.cardWidth + chooserScope.cardSpacing)
                                height: parent.height

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 250
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Repeater {
                                    model: chooserScope.wallpaperList

                                    Item {
                                        id: card
                                        required property int index
                                        required property var modelData

                                        property real distFromCenter: index - chooserScope.currentIndex
                                        property bool isSelected: index === chooserScope.currentIndex

                                        // Arc: parabolic vertical drop at edges
                                        property real arcY: distFromCenter * distFromCenter * 6

                                        // Slight rotation toward center
                                        property real arcRotation: distFromCenter * -2.5

                                        // Scale: center is largest
                                        property real cardScale: {
                                            const base = Math.max(0.7, 1.0 - Math.abs(distFromCenter) * 0.06);
                                            return cardMouse.pressed ? base * 0.95 : base;
                                        }

                                        // Opacity: edges fade
                                        property real cardOpacity: Math.max(0.3, 1.0 - Math.abs(distFromCenter) * 0.12)

                                        x: index * (chooserScope.cardWidth + chooserScope.cardSpacing)
                                        y: arcY
                                        width: chooserScope.cardWidth
                                        height: chooserScope.cardHeight + 28 // thumbnail + label

                                        scale: cardScale
                                        opacity: cardOpacity
                                        z: 100 - Math.abs(distFromCenter)

                                        transform: Rotation {
                                            angle: card.arcRotation
                                            origin.x: card.width / 2
                                            origin.y: card.height
                                        }

                                        Behavior on y {
                                            NumberAnimation {
                                                duration: 250
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 200
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                        SquishBehavior on scale {}

                                        // Card visual
                                        Rectangle {
                                            id: cardBg
                                            anchors.top: parent.top
                                            width: chooserScope.cardWidth
                                            height: chooserScope.cardHeight
                                            radius: Spacing.spacing8
                                            color: Colors.pillBackground
                                            border.width: card.isSelected ? 2 : 1
                                            border.color: card.isSelected ? Colors.accentColor : cardMouse.containsMouse ? Colors.pillBorder : Qt.rgba(1, 1, 1, 0.1)

                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.margins: cardBg.border.width
                                                radius: cardBg.radius - cardBg.border.width
                                                color: "transparent"
                                                clip: true
                                                layer.enabled: true

                                                Image {
                                                    anchors.fill: parent
                                                    source: "file://" + modelData
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    sourceSize: Qt.size(chooserScope.cardWidth * 2, chooserScope.cardHeight * 2)

                                                    opacity: status === Image.Ready ? 1 : 0
                                                    Behavior on opacity {
                                                        NumberAnimation {
                                                            duration: 200
                                                            easing.type: Easing.OutCubic
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Wallpaper name label
                                        Text {
                                            anchors.top: cardBg.bottom
                                            anchors.topMargin: Spacing.spacing4
                                            anchors.horizontalCenter: cardBg.horizontalCenter
                                            width: chooserScope.cardWidth - Spacing.spacing8
                                            text: {
                                                const parts = modelData.split("/");
                                                const filename = parts[parts.length - 1];
                                                return filename.replace(/\.[^.]+$/, "");
                                            }
                                            font.family: Typography.fontFamily
                                            font.pixelSize: Typography.fontSize12
                                            font.weight: card.isSelected ? Font.Bold : Font.Normal
                                            color: card.isSelected ? Colors.textColor : Colors.textColorMuted
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                        }

                                        MouseArea {
                                            id: cardMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: chooserScope.previewCard(card.index)
                                        }
                                    }
                                }
                            }
                        }

                        // Button row
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Spacing.spacing12

                            // Wallpaper hinzufügen (open folder)
                            Rectangle {
                                width: 190
                                height: 36
                                radius: Spacing.spacing8
                                color: Colors.pillBackground
                                border.width: 1
                                border.color: Colors.pillBorder

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: addMouse.pressed ? Colors.hoverItemPressed : addMouse.containsMouse ? Colors.hoverItemHovered : "transparent"
                                }

                                scale: addMouse.pressed ? 0.92 : 1.0
                                SquishBehavior on scale {}

                                Text {
                                    anchors.centerIn: parent
                                    text: "Hintergrund hinzufügen"
                                    font.family: Typography.fontFamily
                                    font.pixelSize: Typography.fontSize14
                                    font.weight: Font.Bold
                                    color: Colors.textColor
                                }

                                MouseArea {
                                    id: addMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        chooserScope.cancel();
                                        openFolderProc.running = true;
                                    }
                                }
                            }

                            // Abbrechen (Cancel)
                            Rectangle {
                                width: 140
                                height: 36
                                radius: Spacing.spacing8
                                color: Colors.pillBackground
                                border.width: 1
                                border.color: cancelMouse.containsMouse || cancelMouse.pressed ? Colors.pillBorder : Colors.pillBorder

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: cancelMouse.pressed ? Colors.hoverItemPressed : cancelMouse.containsMouse ? Colors.hoverItemHovered : "transparent"
                                }

                                scale: cancelMouse.pressed ? 0.92 : 1.0
                                SquishBehavior on scale {}

                                Text {
                                    anchors.centerIn: parent
                                    text: "Abbrechen"
                                    font.family: Typography.fontFamily
                                    font.pixelSize: Typography.fontSize14
                                    font.weight: Font.Bold
                                    color: Colors.textColor
                                }

                                MouseArea {
                                    id: cancelMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: chooserScope.cancel()
                                }
                            }

                            // Anwenden (Apply)
                            Rectangle {
                                width: 140
                                height: 36
                                radius: Spacing.spacing8
                                color: Colors.pillBackground
                                border.width: 1
                                border.color: applyMouse.containsMouse || applyMouse.pressed ? Colors.pillBorder : Colors.pillBorder

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: applyMouse.pressed ? Colors.hoverItemPressed : applyMouse.containsMouse ? Colors.hoverItemHovered : "transparent"
                                }

                                scale: applyMouse.pressed ? 0.92 : 1.0
                                SquishBehavior on scale {}

                                Text {
                                    anchors.centerIn: parent
                                    text: "Anwenden"
                                    font.family: Typography.fontFamily
                                    font.pixelSize: Typography.fontSize14
                                    font.weight: Font.Bold
                                    color: Colors.textColor
                                }

                                MouseArea {
                                    id: applyMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: chooserScope.apply()
                                }
                            }
                        }
                    }
                }
            }
        }

        Connections {
            target: carouselReveal
            function onHidden() {
                chooserWindow.hideComplete = true;
            }
        }

        Connections {
            target: chooserScope
            function onChooserVisibleChanged() {
                if (chooserScope.chooserVisible) {
                    chooserWindow.hideComplete = false;
                    fullArea.focus = true;
                }
            }
        }
    }
}
