import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import "../"

// Design picker. Toggles Globals.designTheme between the classic and neo shells.
// Wallpaper-chooser shaped: full-screen dim, bottom card row, live preview,
// Apply persists, Cancel restores. Opened via `qs ipc call theme toggle`.
// Only the app launcher reacts to the choice now; other windows follow later.
Scope {
    id: switcherScope

    property bool switcherVisible: false
    property string originalTheme: "classic"
    property int currentIndex: 0

    // key drives Globals.designTheme; the mini-preview is a hand-drawn mock.
    readonly property var options: [
        {
            key: "classic",
            label: "Klassisch",
            hint: "Transparente Pillen, weiche Kanten"
        },
        {
            key: "neo",
            label: "Neobrutalismus",
            hint: "Creme-Papier, harte Schatten"
        }
    ]

    readonly property int cardWidth: 300
    readonly property int cardHeight: 200

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor;
        return mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? null) : null;
    }

    function open() {
        originalTheme = Globals.designTheme;
        currentIndex = Math.max(0, options.findIndex(o => o.key === Globals.designTheme));
        const s = focusedScreen();
        if (s)
            switcherWindow.screen = s;
        switcherVisible = true;
    }

    // Live preview: the launcher variant swaps immediately on selection.
    function previewOption(idx) {
        if (idx < 0 || idx >= options.length)
            return;
        currentIndex = idx;
        Globals.designTheme = options[idx].key;
    }

    function apply() {
        ThemePersist.save(options[currentIndex].key);
        close();
    }

    function cancel() {
        Globals.designTheme = originalTheme;
        close();
    }

    function close() {
        switcherScope.switcherVisible = false;
    }

    IpcHandler {
        target: "theme"

        function toggle() {
            if (!switcherScope.switcherVisible)
                switcherScope.open();
            else
                switcherScope.cancel();
        }
    }

    PanelWindow {
        id: switcherWindow
        visible: switcherScope.switcherVisible || !hideComplete
        property bool hideComplete: true

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        exclusiveZone: 0
        focusable: true
        WlrLayershell.keyboardFocus: switcherScope.switcherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        AutoCloseOnFocusLoss {
            watch: fullArea
            armed: switcherScope.switcherVisible
            onLost: switcherScope.cancel()
        }

        mask: Region {
            item: switcherScope.switcherVisible ? fullArea : emptyMask
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

            Keys.onEscapePressed: switcherScope.cancel()
            Keys.onReturnPressed: switcherScope.apply()
            Keys.onLeftPressed: switcherScope.previewOption(switcherScope.currentIndex - 1)
            Keys.onRightPressed: switcherScope.previewOption(switcherScope.currentIndex + 1)

            // Dim + swallow background clicks.
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.35)
                MouseArea {
                    anchors.fill: parent
                }
            }

            PopReveal {
                id: cardReveal
                anchors.centerIn: parent
                width: content.width
                height: content.height
                showing: switcherScope.switcherVisible
                transformOriginValue: Item.Center
                slideOffset: Spacing.spacing16

                Item {
                    id: content
                    width: contentCol.width
                    height: contentCol.height

                    MouseArea {
                        anchors.fill: parent
                    }

                    Column {
                        id: contentCol
                        spacing: Spacing.spacing24

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Design wählen"
                            font.family: Typography.fontFamily
                            font.pixelSize: Typography.fontSize24
                            font.weight: Font.Bold
                            color: Colors.textColor
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Spacing.spacing24

                            Repeater {
                                model: switcherScope.options

                                Item {
                                    id: card
                                    required property int index
                                    required property var modelData
                                    readonly property bool selected: switcherScope.currentIndex === index
                                    // Sized to the visual stack; MouseArea fills it as a sibling
                                    // (a fill anchor inside a Column is rejected).
                                    implicitWidth: cardCol.implicitWidth
                                    implicitHeight: cardCol.implicitHeight

                                    scale: cardMouse.pressed ? 0.97 : 1.0
                                    SquishBehavior on scale {}

                                  Column {
                                    id: cardCol
                                    spacing: Spacing.spacing8

                                    // Preview frame.
                                    Rectangle {
                                        width: switcherScope.cardWidth
                                        height: switcherScope.cardHeight
                                        radius: Spacing.spacing12
                                        color: Colors.pillBackground
                                        border.width: card.selected ? 2 : 1
                                        border.color: card.selected ? Colors.accentColor : cardMouse.containsMouse ? Colors.pillBorder : Qt.rgba(1, 1, 1, 0.1)

                                        // Hover/press wash.
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: cardMouse.pressed ? Colors.hoverItemPressed : cardMouse.containsMouse ? Colors.hoverItemHovered : "transparent"
                                        }

                                        // --- Classic mock: translucent dark launcher ---
                                        Rectangle {
                                            visible: card.modelData.key === "classic"
                                            anchors.centerIn: parent
                                            width: parent.width - Spacing.spacing40
                                            height: parent.height - Spacing.spacing40
                                            radius: Spacing.spacing12
                                            color: Qt.rgba(0.1, 0.1, 0.12, 0.85)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.18)

                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: Spacing.spacing12
                                                spacing: Spacing.spacing8

                                                Rectangle {
                                                    width: parent.width
                                                    height: 18
                                                    radius: 9
                                                    color: Qt.rgba(1, 1, 1, 0.08)
                                                }
                                                Repeater {
                                                    model: 3
                                                    Rectangle {
                                                        required property int index
                                                        width: parent.width
                                                        height: 22
                                                        radius: Spacing.spacing8
                                                        color: index === 0 ? Colors.accentColor : Qt.rgba(1, 1, 1, 0.06)
                                                    }
                                                }
                                            }
                                        }

                                        // --- Neo mock: cream paper, black border, offset shadow ---
                                        Item {
                                            visible: card.modelData.key === "neo"
                                            anchors.centerIn: parent
                                            width: parent.width - Spacing.spacing40
                                            height: parent.height - Spacing.spacing40

                                            Rectangle {
                                                x: 5
                                                y: 5
                                                width: paper.width
                                                height: paper.height
                                                radius: 6
                                                color: "#111111"
                                            }
                                            Rectangle {
                                                id: paper
                                                width: parent.width - 5
                                                height: parent.height - 5
                                                radius: 6
                                                color: "#fffdf5"
                                                border.width: 3
                                                border.color: "#111111"

                                                Column {
                                                    anchors.fill: parent
                                                    anchors.margins: Spacing.spacing8
                                                    spacing: Spacing.spacing8

                                                    Rectangle {
                                                        width: parent.width
                                                        height: 18
                                                        radius: 4
                                                        color: "#f0eede"
                                                        border.width: 2
                                                        border.color: "#111111"
                                                    }
                                                    Repeater {
                                                        model: 3
                                                        Rectangle {
                                                            required property int index
                                                            width: parent.width
                                                            height: 22
                                                            radius: 4
                                                            color: index === 0 ? Colors.accentColor : "transparent"
                                                            border.width: 2
                                                            border.color: "#111111"
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: card.modelData.label
                                        font.family: Typography.fontFamily
                                        font.pixelSize: Typography.fontSize16
                                        font.weight: card.selected ? Font.Bold : Font.Normal
                                        color: card.selected ? Colors.textColor : Colors.textColorMuted
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: card.modelData.hint
                                        font.family: Typography.fontFamily
                                        font.pixelSize: Typography.fontSize12
                                        font.weight: Font.Normal
                                        color: Colors.textColorMuted
                                    }
                                  }

                                    MouseArea {
                                        id: cardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: switcherScope.previewOption(card.index)
                                        onDoubleClicked: switcherScope.apply()
                                    }
                                }
                            }
                        }

                        // Button row.
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Spacing.spacing12

                            Rectangle {
                                width: 140
                                height: 36
                                radius: Spacing.spacing8
                                color: Colors.pillBackground
                                border.width: 1
                                border.color: Colors.pillBorder

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
                                    onClicked: switcherScope.cancel()
                                }
                            }

                            Rectangle {
                                width: 140
                                height: 36
                                radius: Spacing.spacing8
                                color: Colors.pillBackground
                                border.width: 1
                                border.color: Colors.pillBorder

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
                                    onClicked: switcherScope.apply()
                                }
                            }
                        }
                    }
                }
            }
        }

        Connections {
            target: cardReveal
            function onHidden() {
                switcherWindow.hideComplete = true;
            }
        }

        Connections {
            target: switcherScope
            function onSwitcherVisibleChanged() {
                if (switcherScope.switcherVisible) {
                    switcherWindow.hideComplete = false;
                    fullArea.focus = true;
                }
            }
        }
    }
}
