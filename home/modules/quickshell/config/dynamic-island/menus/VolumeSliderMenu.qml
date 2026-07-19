pragma ComponentBehavior: Bound

import QtQuick
import "../"
import "../base"

Item {
    id: root

    // Behavior lives in the controller. Instantiated once, tracker + models survive here.
    VolumeMenuController {
        id: controller
    }

    // Read by Bar.qml to keep the menu open while a slider is held.
    readonly property bool sliderActive: masterSlider.pressed || root._anyAppSliderPressed

    // Aggregated over live rows, never counted from press/release edges.
    // A row destroyed mid-drag emits no release.
    // A +1/-1 counter then leaks a permanent +1, latching sliderActive true,
    // and the menu never closes again.
    //
    // itemAt is not a binding dependency, so row churn re-runs this via _appRowGeneration.
    // Repeater drops a removed row before it signals, and a fresh row cannot be pressed.
    property int _appRowGeneration: 0
    readonly property bool _anyAppSliderPressed: {
        root._appRowGeneration;
        for (let i = 0; i < appRepeater.count; i++) {
            const row = appRepeater.itemAt(i);
            if (row && row.sliderPressed)
                return true;
        }
        return false;
    }

    readonly property int contentPadding: Spacing.spacing12

    // Neo card draws its offset shadow inside the bottom-right gutter.
    // Pad size by shadowOffset so paper stays 300 wide, content unchanged (0 in classic).
    implicitWidth: 300 + Shape.shadowOffset
    implicitHeight: mainLayout.height + 2 * contentPadding + Shape.shadowOffset

    property bool outputExpanded: false

    Card {
        id: card
        anchors.fill: parent

        Column {
            id: mainLayout
            x: root.contentPadding
            y: root.contentPadding
            width: card.paperWidth - 2 * root.contentPadding
            spacing: Spacing.spacing8

            Row {
                width: parent.width
                height: 40
                spacing: Spacing.spacing8

                VolumeMuteButton {
                    id: muteButton
                    width: 32
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter

                    iconSource: controller.iconSource
                    onTapped: controller.toggleMute()
                }

                StepSlider {
                    id: masterSlider
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - muteButton.width - pctLabel.width - 2 * parent.spacing
                    externalValue: controller.audioNode?.volume ?? 0
                    stepSize: 0.05
                    isMuted: controller.muted

                    onMoved: newValue => controller.setMasterVolume(newValue)
                }

                Label {
                    id: pctLabel
                    text: controller.volume + " %"
                    width: 40
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Colors.separatorColor
            }

            // Output device
            Item {
                id: outputHeader
                width: parent.width
                height: 32

                scale: outputTap.pressed ? 0.97 : 1.0
                SquishBehavior on scale {}

                // Button toggle bg. Squish scale carries press feedback.
                ButtonBg {
                    hovered: outputHover.hovered
                }

                Label {
                    text: "Ausgabe"
                    font.pixelSize: Typography.fontSize12
                    color: Colors.textColorMuted
                    font.weight: Font.Normal
                    anchors {
                        left: parent.left
                        leftMargin: Spacing.spacing8
                        verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    anchors {
                        right: parent.right
                        rightMargin: Spacing.spacing8
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Spacing.spacing6

                    Label {
                        text: controller.defaultSinkDescription
                        font.pixelSize: Typography.fontSize12
                        color: Colors.textColor
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 160)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    ExpandArrow {
                        expanded: root.outputExpanded
                        collapsedRotation: 0
                        expandedRotation: 180
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler {
                    id: outputHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    id: outputTap
                    onTapped: root.outputExpanded = !root.outputExpanded
                }
            }

            // Output device list (expandable)
            ExpandSection {
                expanded: root.outputExpanded

                Column {
                    width: parent.width

                    Repeater {
                        model: controller.outputDevices

                        VolumeOutputDeviceRow {
                            required property var modelData
                            outputDevice: modelData
                            defaultSinkId: controller.defaultSinkId

                            onSinkActivated: sinkNode => controller.activateSink(sinkNode)
                            onBluetoothActivated: (deviceName, mac) => controller.activateBluetooth(deviceName, mac)
                        }
                    }
                }
            }

            Rectangle {
                visible: controller.streamNodes.length > 0
                width: parent.width
                height: 1
                color: Colors.separatorColor
            }

            // Per-application volume
            Label {
                visible: controller.streamNodes.length > 0
                text: "Anwendungen"
                font.pixelSize: Typography.fontSize12
                color: Colors.textColorMuted
                font.weight: Font.Normal
            }

            Column {
                id: appsColumn
                visible: controller.streamNodes.length > 0
                width: parent.width
                spacing: Spacing.spacing12

                Repeater {
                    id: appRepeater
                    model: controller.streamNodes

                    onItemAdded: root._appRowGeneration++
                    onItemRemoved: root._appRowGeneration++

                    VolumeApplicationVolumeRow {
                        required property var modelData
                        streamNode: modelData
                        controller: controller
                    }
                }
            }
        }
    }
}
