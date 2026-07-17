import QtQuick
import "../"
import "../base"
import "../animations"

// Fullscreen overlay listing apps being gracefully closed.
// View only: closing, polling and postCmd live in the GracefulShutdown singleton.

PopReveal {
    id: root

    signal cancelled

    // Fullscreen reveal, slower than PopReveal's popup defaults.
    edge: Qt.BottomEdge
    showDuration: 200
    hideDuration: 150
    // Fullscreen dim scales from its middle.
    // Edge-derived origin would drag the whole screen toward one side.
    transformOrigin: Item.Center

    focus: visible

    Keys.onEscapePressed: root.abort()

    // cancel() clears active, stopping the poll timer through its binding.
    function abort() {
        GracefulShutdown.cancel();
        root.cancelled();
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)

        OverlayExitButton {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Spacing.spacing24
            onTapped: root.abort()
        }

        Column {
            anchors.centerIn: parent
            spacing: Spacing.spacing24
            width: 320

            OverlaySpinner {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 60
                // Frozen spinner marks giving up.
                spinning: root.visible && !GracefulShutdown.stalled
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: GracefulShutdown.label
                font.family: Typography.fontFamily
                font.weight: Font.Bold
                font.pixelSize: Typography.fontSize16
                color: Colors.textColor
            }

            Column {
                width: parent.width
                spacing: Spacing.spacing4

                Text {
                    text: GracefulShutdown.stalled ? "Einige Apps reagieren nicht." : "Apps werden geschlossen..."
                    font.family: Typography.fontFamily
                    font.weight: Font.Normal
                    font.pixelSize: Typography.fontSize12
                    color: Colors.textColorMuted
                }

                Repeater {
                    model: GracefulShutdown.apps

                    Rectangle {
                        id: appRow

                        required property string appClass
                        required property string title
                        required property bool alive

                        width: parent.width
                        height: 32
                        radius: Spacing.spacing4
                        color: Colors.hoverItemHovered
                        opacity: appRow.alive ? 1.0 : 0.4

                        // Rows update in place, so a delegate survives long enough to fade.
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }

                        Row {
                            id: infoRow
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: statusIcon.left
                            anchors.leftMargin: Spacing.spacing8
                            anchors.rightMargin: Spacing.spacing8
                            spacing: Spacing.spacing8

                            Text {
                                id: classLabel
                                text: appRow.appClass
                                font.family: Typography.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: Typography.fontSize12
                                color: Colors.textColor
                                width: 100
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: appRow.title
                                font.family: Typography.fontFamily
                                font.weight: Font.Normal
                                font.pixelSize: Typography.fontSize12
                                color: Colors.textColorMuted
                                elide: Text.ElideRight
                                width: infoRow.width - classLabel.width - infoRow.spacing
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Two icons, not one swapped source: rotation freezes at its last
                        // angle when the spinner stops, tilting a shared icon.
                        Item {
                            id: statusIcon
                            anchors.right: parent.right
                            anchors.rightMargin: Spacing.spacing8
                            anchors.verticalCenter: parent.verticalCenter
                            width: Typography.fontSize12
                            height: Typography.fontSize12

                            OverlaySpinner {
                                anchors.centerIn: parent
                                size: Typography.fontSize12
                                color: Colors.textColorMuted
                                visible: appRow.alive
                            }

                            TintedIcon {
                                anchors.centerIn: parent
                                source: "../icons/icons8-done.svg"
                                size: Typography.fontSize12
                                color: Colors.accentColor
                                visible: !appRow.alive
                            }
                        }
                    }
                }
            }

            // Only path past a window that refuses to close.
            Item {
                width: parent.width
                height: 36
                visible: GracefulShutdown.stalled
                scale: proceedTap.pressed ? 0.96 : 1.0

                SquishBehavior on scale {}

                Rectangle {
                    anchors.fill: parent
                    radius: Spacing.spacing8
                    color: proceedTap.pressed ? Colors.hoverItemPressed : proceedHover.hovered ? Colors.hoverItemHovered : "transparent"
                    // Border stays lit: nothing else marks this as pressable.
                    border.color: proceedHover.hovered || proceedTap.pressed ? Colors.accentColor : Colors.pillBorder
                }

                Text {
                    anchors.centerIn: parent
                    text: "Trotzdem fortfahren"
                    font.family: Typography.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: Typography.fontSize12
                    color: Colors.textColor
                }

                HoverHandler {
                    id: proceedHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: proceedTap
                    onTapped: GracefulShutdown.proceed()
                }
            }
        }
    }
}
