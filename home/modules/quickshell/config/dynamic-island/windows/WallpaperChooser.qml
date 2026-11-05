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
    // Maps a wallpaper path to its accent color, as far as resolved.
    property var wallpaperAccents: ({})
    property int nextAccentIndex: 0
    // Maps a wallpaper path to the mean gray behind the name label, 0..1.
    property var labelBackdrops: ({})

    readonly property real cardHeightRatio: 0.41
    readonly property real cardAspect: 0.365
    // chooserWindow.height holds a placeholder while unmapped.
    readonly property int cardHeight: Math.round((chooserWindow.screen?.height ?? chooserWindow.height) * cardHeightRatio)
    readonly property int cardWidth: Math.round(cardHeight * cardAspect)
    // Sized for the tallest screen, so moving the chooser between monitors decodes nothing again.
    // Floor applies while Quickshell.screens is empty: sourceSize 0 decodes the originals at full size.
    readonly property int thumbnailHeight: Math.round(Quickshell.screens.reduce((tallest, s) => Math.max(tallest, s.height), 1080) * cardHeightRatio)
    readonly property int cardSpacing: Spacing.spacing8
    // Gray at which dark and light text reach equal contrast (WCAG luminance 0.179, gamma-encoded).
    readonly property real labelBackdropThreshold: 0.46
    // Distance from center, in cards, at which the lens flattens out.
    readonly property real lensReach: 8
    // Scale of every card past lensReach.
    readonly property real lensFloor: 0.4

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

    // Raised cosine: scale of a card `dist` cards away from center, 1 at center.
    function lensScale(dist) {
        const progress = Math.min(Math.abs(dist) / lensReach, 1);
        return lensFloor + (1 - lensFloor) * (1 + Math.cos(Math.PI * progress)) / 2;
    }

    // Pixels from center to the card's center.
    // Integral of lensScale over the card widths, so the gap stays cardSpacing at any scale.
    function lensOffset(dist) {
        const inside = Math.min(Math.abs(dist), lensReach);
        const insideWidths = (1 + lensFloor) / 2 * inside + (1 - lensFloor) / 2 * lensReach / Math.PI * Math.sin(Math.PI * inside / lensReach);
        const outsideWidths = lensFloor * (Math.abs(dist) - inside);
        return Math.sign(dist) * (cardWidth * (insideWidths + outsideWidths) + cardSpacing * Math.abs(dist));
    }

    function resolveNextAccent() {
        if (nextAccentIndex < wallpaperList.length)
            accentResolver.resolve(wallpaperList[nextAccentIndex++]);
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
        Globals.wallpaperPreviewing = true;

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

        // WallpaperPreview already shows it. close() hands it to hyprpaper.
        close();
    }

    function cancel() {
        // restoreWallpaper() already resets Globals.wallpaperPath.
        restoreWallpaper();
        close();
    }

    function close() {
        chooserScope.chooserVisible = false;
        Globals.wallpaperPreviewing = false;
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

        // Setting the global triggers WallpaperPreview and WallpaperAccent
        Globals.wallpaperPath = "file://" + path;
    }

    function restoreWallpaper() {
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
        onExited: {
            chooserScope.wallpaperListChanged();
            chooserScope.resolveNextAccent();
            labelBackdropProc.running = true;
        }
    }

    Process {
        id: labelBackdropProc

        property var backdrops: ({})

        // jpeg:size decodes the originals at a fraction of their size.
        // Crop on the 64x36 downscale covers the band under the center card.
        command: ["bash", "-c", "for f; do echo \"$(magick -define jpeg:size=256x144 \"$f\" -resize 64x36! -crop 8x3+28+25 +repage -colorspace Gray -resize 1x1! -format '%[fx:mean]' info:) $f\"; done", "bash"].concat(chooserScope.wallpaperList)
        stdout: SplitParser {
            onRead: data => {
                const separator = data.indexOf(" ");
                labelBackdropProc.backdrops[data.substring(separator + 1)] = parseFloat(data);
            }
        }
        onExited: chooserScope.labelBackdrops = backdrops
    }

    WallpaperAccentResolver {
        id: accentResolver
        onFinished: (path, color) => {
            if (color.length > 0)
                chooserScope.wallpaperAccents = Object.assign({}, chooserScope.wallpaperAccents, {
                    [path]: color
                });
            Qt.callLater(chooserScope.resolveNextAccent);
        }
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
                            readonly property real exactLeft: strip.width / 2 + centerOffset - chooserScope.cardWidth * lensScale / 2
                            readonly property bool isSelected: index === chooserScope.currentIndex
                            readonly property color accent: chooserScope.wallpaperAccents[modelData] ?? Colors.accentColor

                            // Whole pixels instead of a scale transform.
                            // A fractional scale rounds the outline to different widths per side.
                            x: Math.round(exactLeft)
                            y: Math.round((strip.height - height) / 2)
                            width: Math.round(exactLeft + chooserScope.cardWidth * lensScale) - x
                            height: 2 * Math.round(chooserScope.cardHeight * lensScale / 2)

                            // Fades across the last card width before the screen edge.
                            opacity: Math.max(0, Math.min(1, (strip.width / 2 - Math.abs(centerOffset)) / width))
                            visible: opacity > 0

                            Rectangle {
                                id: cardBg
                                anchors.fill: parent
                                color: Colors.pillBackground
                                border.width: card.isSelected ? (Shape.usesBlur ? 2 : Shape.borderWidth) : (Shape.usesBlur ? 1 : Shape.thinBorderWidth)
                                border.color: cardMouse.containsMouse ? Qt.lighter(card.accent, 1.25) : card.accent

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
                    color: {
                        const backdrop = chooserScope.labelBackdrops[chooserScope.wallpaperList[chooserScope.currentIndex]];
                        if (backdrop === undefined)
                            return Colors.textColor;
                        return backdrop > chooserScope.labelBackdropThreshold ? NeoTokens.ink : NeoTokens.paper;
                    }
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
