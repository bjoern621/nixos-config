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
    // currentIndex plus whole laps of the ring, so the strip crosses the list's seam the short way.
    property int scrollTarget: 0
    property var wallpaperList: []

    readonly property real cardHeightRatio: 0.41
    readonly property real cardAspect: 0.365
    // chooserWindow.height holds a placeholder while unmapped.
    readonly property int cardHeight: Math.round((chooserWindow.screen?.height ?? chooserWindow.height) * cardHeightRatio)
    readonly property int cardWidth: Math.round(cardHeight * cardAspect)
    // Sized for the tallest screen, so moving the chooser between monitors decodes nothing again.
    // Floor applies while Quickshell.screens is empty: sourceSize 0 decodes the originals at full size.
    readonly property int thumbnailHeight: Math.round(Quickshell.screens.reduce((tallest, s) => Math.max(tallest, s.height), 1080) * cardHeightRatio)
    readonly property int cardSpacing: Spacing.spacing8
    // Distance from center, in cards, at which a card drops to half size.
    readonly property real lensFalloff: 5.5

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

    function wrapIndex(i) {
        const n = wallpaperList.length;
        return ((i % n) + n) % n;
    }

    // Shortest signed way around the ring.
    function ringDistance(dist) {
        const n = wallpaperList.length;
        return wrapIndex(dist + n / 2) - n / 2;
    }

    // Scale of a card `dist` cards away from center, 1 at center.
    function lensScale(dist) {
        return 1 / (1 + (dist / lensFalloff) * (dist / lensFalloff));
    }

    // Integral of lensScale, so the gaps between cards shrink with the cards.
    // Pixels from center to the card's center.
    function lensOffset(dist) {
        return (cardWidth + cardSpacing) * lensFalloff * Math.atan(dist / lensFalloff);
    }

    function wallpaperName(path) {
        const parts = path.split("/");
        return parts[parts.length - 1].replace(/\.[^.]+$/, "");
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
                moveSelection(i);
                break;
            }
        }

        // Switch to empty workspace to hide windows
        workspaceProc.command = ["hyprctl", "dispatch", 'hl.dsp.focus({ workspace = "name:wallpaper" })'];
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
            workspaceProc.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + previousWorkspaceId + " })"];
            workspaceProc.running = true;
        }
    }

    function navigate(step) {
        if (chooserScope.wallpaperList.length > 0)
            previewCard(wrapIndex(chooserScope.currentIndex + step));
    }

    function moveSelection(idx) {
        chooserScope.scrollTarget += ringDistance(idx - chooserScope.scrollTarget);
        chooserScope.currentIndex = idx;
    }

    function previewCard(idx) {
        if (idx < 0 || idx >= chooserScope.wallpaperList.length)
            return;
        moveSelection(idx);

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
        command: ["bash", "-c", "ls -1 ~/.local/share/wallpapers/*.jpg ~/.local/share/wallpapers/*.png ~/.local/share/wallpapers/*.webp 2>/dev/null | sort"]
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
            Keys.onLeftPressed: chooserScope.navigate(-1)
            Keys.onRightPressed: chooserScope.navigate(1)

            // Absorb background clicks so they don't pass through the layer surface
            MouseArea {
                anchors.fill: parent
            }

            // Lens strip over the middle of the screen
            PopReveal {
                id: carouselReveal
                anchors.fill: parent
                showing: chooserScope.chooserVisible
                transformOriginValue: Item.Center
                slideOffset: -Spacing.spacing16

                Item {
                    id: strip
                    anchors.fill: parent

                    // Fractional while gliding, so every card rides the lens between two selections.
                    property real scrollPos: chooserScope.scrollTarget
                    SquishBehavior on scrollPos {
                        duration: 250
                    }

                    Repeater {
                        model: chooserScope.wallpaperList

                        Item {
                            id: card
                            required property int index
                            required property var modelData

                            readonly property real distFromCenter: chooserScope.ringDistance(index - strip.scrollPos)
                            readonly property real centerOffset: chooserScope.lensOffset(distFromCenter)
                            readonly property real lensScale: chooserScope.lensScale(distFromCenter)
                            readonly property bool isSelected: index === chooserScope.currentIndex

                            x: (strip.width - width) / 2 + centerOffset
                            anchors.verticalCenter: parent.verticalCenter
                            width: chooserScope.cardWidth
                            height: chooserScope.cardHeight
                            scale: lensScale

                            // Fades across the last card width before the screen edge.
                            opacity: Math.max(0, Math.min(1, (strip.width / 2 - Math.abs(centerOffset)) / (width * lensScale)))
                            visible: opacity > 0

                            Rectangle {
                                id: cardBg
                                anchors.fill: parent
                                color: Colors.pillBackground
                                // Neo: visible ink border, thick accent when selected.
                                border.width: card.isSelected ? (Shape.usesBlur ? 2 : Shape.borderWidth) : (Shape.usesBlur ? 1 : Shape.thinBorderWidth)
                                border.color: card.isSelected ? Colors.accentColor : cardMouse.containsMouse ? Colors.pillBorder : (Shape.usesBlur ? Qt.rgba(1, 1, 1, 0.1) : Colors.pillBorder)

                                scale: cardMouse.pressed ? 0.97 : 1.0
                                SquishBehavior on scale {}

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: cardBg.border.width
                                    source: "file://" + card.modelData
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize: Qt.size(chooserScope.thumbnailHeight * chooserScope.cardAspect, chooserScope.thumbnailHeight)

                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 200
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
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

                // Wallpaper name label
                Text {
                    anchors.top: parent.verticalCenter
                    anchors.topMargin: chooserScope.cardHeight / 2 + Spacing.spacing16
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: chooserScope.cardWidth * 3
                    text: chooserScope.wallpaperName(chooserScope.wallpaperList[chooserScope.currentIndex] ?? "")
                    font.family: Typography.fontFamily
                    font.pixelSize: Typography.fontSize14
                    font.weight: Font.Bold
                    color: Colors.textColor
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                // Button row
                Row {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Spacing.spacing40
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Spacing.spacing12

                    // Wallpaper hinzufügen (open folder)
                    StaticButton {
                        width: 190 + Shape.buttonShadowOffset
                        height: 36 + Shape.buttonShadowOffset
                        centered: true
                        fontPixelSize: Typography.fontSize14
                        label: "Hintergrund hinzufügen"
                        onClicked: {
                            chooserScope.cancel();
                            openFolderProc.running = true;
                        }
                    }

                    // Abbrechen (Cancel)
                    StaticButton {
                        width: 140 + Shape.buttonShadowOffset
                        height: 36 + Shape.buttonShadowOffset
                        centered: true
                        fontPixelSize: Typography.fontSize14
                        label: "Abbrechen"
                        onClicked: chooserScope.cancel()
                    }

                    // Anwenden (Apply)
                    StaticButton {
                        width: 140 + Shape.buttonShadowOffset
                        height: 36 + Shape.buttonShadowOffset
                        centered: true
                        fontPixelSize: Typography.fontSize14
                        label: "Anwenden"
                        onClicked: chooserScope.apply()
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
