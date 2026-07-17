pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "../"
import "../base"
import "BluetoothUtils.js" as BluetoothUtils

Item {
    id: root

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

    implicitWidth: 300
    implicitHeight: mainLayout.height + 2 * contentPadding

    readonly property var sinkNodes: {
        const nodes = Pipewire.nodes.values;
        const result = [];
        if (!nodes)
            return result;
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n.isSink && !n.isStream)
                result.push(n);
        }
        return result;
    }

    readonly property var streamNodes: {
        const nodes = Pipewire.nodes.values;
        const result = [];
        if (!nodes)
            return result;
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n.isStream && n.audio)
                result.push(n);
        }
        return result;
    }

    // Connect and audio switch live in BluetoothConnector: machine-global state, menu is per-screen.
    readonly property var outputDevices: {
        return BluetoothUtils.buildOutputDevices(root.sinkNodes, BluetoothConnector.targets);
    }

    property bool outputExpanded: false

    // PwObjectTracker keeps audio data current for every node read here.
    PwObjectTracker {
        objects: {
            var list = [];
            if (Pipewire.defaultAudioSink)
                list.push(Pipewire.defaultAudioSink);
            var sinks = root.sinkNodes;
            for (var i = 0; i < sinks.length; i++)
                list.push(sinks[i]);
            var streams = root.streamNodes;
            for (var i = 0; i < streams.length; i++)
                list.push(streams[i]);
            return list;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Spacing.spacing12
        color: Colors.pillBackground
        border.width: 1
        border.color: Colors.pillBorder

        Column {
            id: mainLayout
            x: root.contentPadding
            y: root.contentPadding
            width: parent.width - 2 * root.contentPadding
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

                    iconSource: VolumeService.iconSource
                    onTapped: {
                        if (VolumeService.audioNode)
                            VolumeService.audioNode.muted = !VolumeService.audioNode.muted;
                    }
                }

                StepSlider {
                    id: masterSlider
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - muteButton.width - pctLabel.width - 2 * parent.spacing
                    externalValue: VolumeService.audioNode?.volume ?? 0
                    stepSize: 0.05
                    isMuted: VolumeService.muted

                    onMoved: newValue => {
                        if (VolumeService.audioNode)
                            VolumeService.audioNode.volume = newValue;
                    }
                }

                Label {
                    id: pctLabel
                    text: VolumeService.volume + " %"
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

                Rectangle {
                    anchors.fill: parent
                    radius: Spacing.spacing8
                    color: outputTap.pressed ? Colors.hoverItemPressed : outputHover.hovered ? Colors.hoverItemHovered : "transparent"
                    border.color: outputHover.hovered || outputTap.pressed ? Colors.pillBorder : "transparent"
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
                        text: Pipewire.defaultAudioSink?.description ?? "---"
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
                        model: root.outputDevices

                        VolumeOutputDeviceRow {
                            required property var modelData
                            outputDevice: modelData
                            defaultSinkId: Pipewire.defaultAudioSink?.id ?? -1

                            onSinkActivated: sinkNode => {
                                BluetoothConnector.cancelAutoSwitch();
                                Pipewire.preferredDefaultAudioSink = sinkNode;
                            }
                            onBluetoothActivated: (deviceName, mac) => {
                                BluetoothConnector.connectDevice(deviceName, mac);
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.streamNodes.length > 0
                width: parent.width
                height: 1
                color: Colors.separatorColor
            }

            // Per-application volume
            Label {
                visible: root.streamNodes.length > 0
                text: "Anwendungen"
                font.pixelSize: Typography.fontSize12
                color: Colors.textColorMuted
                font.weight: Font.Normal
            }

            Column {
                id: appsColumn
                visible: root.streamNodes.length > 0
                width: parent.width
                spacing: Spacing.spacing12

                Repeater {
                    id: appRepeater
                    model: root.streamNodes

                    onItemAdded: root._appRowGeneration++
                    onItemRemoved: root._appRowGeneration++

                    VolumeApplicationVolumeRow {
                        required property var modelData
                        streamNode: modelData
                    }
                }
            }
        }
    }
}
