import Quickshell.Services.Pipewire
import QtQuick
import "../"
import "../base"

Item {
    id: root

    readonly property bool sliderActive: masterSlider.pressed || _activeAppSliders > 0
    property int _activeAppSliders: 0

    readonly property int contentPadding: Spacing.spacing12

    implicitWidth: 300
    implicitHeight: mainLayout.height + 2 * contentPadding

    // --- Master audio state ---
    readonly property var audioNode: Pipewire.defaultAudioSink?.audio ?? null
    readonly property int currentVolume: Math.round((audioNode?.volume ?? 0) * 100)
    readonly property bool isMuted: audioNode?.muted ?? false
    readonly property string volumeIconSource: {
        if (isMuted || currentVolume === 0)
            return "../icons/icons8-sound-speaker.svg";
        if (currentVolume <= 33)
            return "../icons/icons8-low-volume.svg";
        if (currentVolume <= 66)
            return "../icons/icons8-volume.svg";
        return "../icons/icons8-audio.svg";
    }

    // --- Filtered node lists ---
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

    property bool outputExpanded: false

    // Track all nodes we need audio data from
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

            // ═══ SECTION 1: Master Volume ═══
            Row {
                width: parent.width
                height: 40
                spacing: Spacing.spacing8

                // Mute toggle button
                Item {
                    id: muteButton
                    width: 32
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter

                    scale: muteTap.pressed ? 0.85 : 1.0
                    SquishBehavior on scale {}

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: muteTap.pressed ? Colors.hoverItemPressed : muteHover.hovered ? Colors.hoverItemHovered : "transparent"
                        border.color: muteHover.hovered || muteTap.pressed ? Colors.pillBorder : "transparent"
                    }

                    ContentReplace {
                        id: muteIconReplace
                        contentKey: root.volumeIconSource
                        anchors.centerIn: parent
                        width: 18
                        height: 18

                        Item {
                            id: muteIconText
                            width: 18
                            height: 18
                            x: 0
                            y: 0

                            TintedIcon {
                                anchors.centerIn: parent
                                size: 18
                                source: muteIconReplace.displayValue
                            }
                        }
                    }

                    HoverHandler {
                        id: muteHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        id: muteTap
                        onTapped: {
                            if (root.audioNode)
                                root.audioNode.muted = !root.audioNode.muted;
                        }
                    }
                }

                // Volume slider
                StepSlider {
                    id: masterSlider
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - muteButton.width - pctLabel.width - 2 * parent.spacing
                    externalValue: root.audioNode?.volume ?? 0
                    stepSize: 0.05
                    isMuted: root.isMuted

                    onMoved: newValue => {
                        if (root.audioNode)
                            root.audioNode.volume = newValue;
                    }
                }

                // Percentage label
                Label {
                    id: pctLabel
                    text: root.currentVolume + " %"
                    width: 40
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // ═══ SEPARATOR ═══
            Rectangle {
                width: parent.width
                height: 1
                color: Colors.separatorColor
            }

            // ═══ SECTION 2: Output Device ═══
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
                        collapsedRotation: 90
                        expandedRotation: -90
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
                    spacing: Spacing.spacing2

                    Repeater {
                        model: root.sinkNodes

                        Item {
                            id: sinkDelegate
                            required property var modelData
                            width: parent ? parent.width : 0
                            height: 32

                            readonly property bool isDefault: modelData.id === (Pipewire.defaultAudioSink?.id ?? -1)

                            scale: sinkTap.pressed ? 0.97 : 1.0
                            SquishBehavior on scale {}

                            Rectangle {
                                anchors.fill: parent
                                radius: Spacing.spacing8
                                color: sinkDelegate.isDefault ? Qt.rgba(1, 1, 1, 0.06) : sinkTap.pressed ? Colors.hoverItemPressed : sinkHover.hovered ? Colors.hoverItemHovered : "transparent"
                                border.color: sinkDelegate.isDefault ? Colors.accentColor : sinkHover.hovered || sinkTap.pressed ? Colors.pillBorder : "transparent"
                            }

                            Row {
                                anchors {
                                    left: parent.left
                                    leftMargin: Spacing.spacing8
                                    right: parent.right
                                    rightMargin: Spacing.spacing8
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: Spacing.spacing8

                                Label {
                                    text: sinkDelegate.modelData.description || sinkDelegate.modelData.name
                                    font.pixelSize: Typography.fontSize12
                                    font.weight: sinkDelegate.isDefault ? Font.Bold : Font.Normal
                                    color: sinkDelegate.isDefault ? Colors.accentColor : Colors.textColor
                                    width: parent.width - parent.spacing - checkIcon.width
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                TintedIcon {
                                    id: checkIcon
                                    source: "../icons/icons8-done.svg"
                                    size: Typography.fontSize12
                                    color: Colors.accentColor
                                    visible: sinkDelegate.isDefault
                                    width: visible ? Typography.fontSize12 : 0
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            HoverHandler {
                                id: sinkHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                id: sinkTap
                                onTapped: {
                                    Pipewire.preferredDefaultAudioSink = sinkDelegate.modelData;
                                    root.outputExpanded = false;
                                }
                            }
                        }
                    }
                }
            }

            // ═══ SEPARATOR (only if there are streams) ═══
            Rectangle {
                visible: root.streamNodes.length > 0
                width: parent.width
                height: 1
                color: Colors.separatorColor
            }

            // ═══ SECTION 3: Applications ═══
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
                    model: root.streamNodes

                    Column {
                        id: appDelegate
                        required property var modelData
                        width: parent ? parent.width : 0
                        spacing: Spacing.spacing4

                        readonly property var appAudio: modelData.audio
                        readonly property int appVolume: Math.round((appAudio?.volume ?? 0) * 100)
                        readonly property bool appMuted: appAudio?.muted ?? false
                        readonly property string appIconSource: {
                            if (appMuted || appVolume === 0)
                                return "../icons/icons8-sound-speaker.svg";
                            if (appVolume <= 33)
                                return "../icons/icons8-low-volume.svg";
                            if (appVolume <= 66)
                                return "../icons/icons8-volume.svg";
                            return "../icons/icons8-audio.svg";
                        }

                        // App name + mute button row
                        Item {
                            width: parent.width
                            height: 24

                            Label {
                                text: appDelegate.modelData.description || appDelegate.modelData.name
                                font.pixelSize: Typography.fontSize12
                                elide: Text.ElideRight
                                anchors {
                                    left: parent.left
                                    right: appMuteBtn.left
                                    rightMargin: Spacing.spacing8
                                    verticalCenter: parent.verticalCenter
                                }
                            }

                            Item {
                                id: appMuteBtn
                                width: 24
                                height: 24
                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }

                                scale: appMuteTap.pressed ? 0.85 : 1.0
                                SquishBehavior on scale {}

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: appMuteTap.pressed ? Colors.hoverItemPressed : appMuteHover.hovered ? Colors.hoverItemHovered : "transparent"
                                    border.color: appMuteHover.hovered || appMuteTap.pressed ? Colors.pillBorder : "transparent"
                                }

                                ContentReplace {
                                    id: appMuteIconReplace
                                    contentKey: appDelegate.appIconSource
                                    width: 16
                                    height: 16
                                    anchors.centerIn: parent

                                    Item {
                                        width: 16
                                        height: 16
                                        x: 0
                                        y: 0

                                        TintedIcon {
                                            anchors.centerIn: parent
                                            size: 16
                                            source: appMuteIconReplace.displayValue
                                        }
                                    }
                                }

                                HoverHandler {
                                    id: appMuteHover
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    id: appMuteTap
                                    onTapped: {
                                        if (appDelegate.appAudio)
                                            appDelegate.appAudio.muted = !appDelegate.appAudio.muted;
                                    }
                                }
                            }
                        }

                        // App slider + percentage row
                        Row {
                            width: parent.width
                            spacing: Spacing.spacing8

                            StepSlider {
                                id: appSlider
                                width: parent.width - appPct.width - parent.spacing
                                anchors.verticalCenter: parent.verticalCenter
                                externalValue: appDelegate.appAudio?.volume ?? 0
                                stepSize: 0.05
                                isMuted: appDelegate.appMuted
                                handleVerticalSize: 16

                                onMoved: newValue => {
                                    if (appDelegate.appAudio)
                                        appDelegate.appAudio.volume = newValue;
                                }
                                onPressedChanged: {
                                    if (pressed)
                                        root._activeAppSliders++;
                                    else
                                        root._activeAppSliders--;
                                }
                            }

                            Label {
                                id: appPct
                                text: appDelegate.appVolume + "%"
                                width: 36
                                horizontalAlignment: Text.AlignRight
                                font.pixelSize: Typography.fontSize12
                                font.weight: Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
