pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick
import "../"
import "../base"
import "BluetoothUtils.js" as BluetoothUtils

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

    // Always-visible Bluetooth targets (paired audio devices).
    readonly property var bluetoothTargets: [
        {
            name: "Anker Soundcore Boost",
            mac: "F4:2B:7D:54:EF:8A"
        },
        {
            name: "LinkBuds S",
            mac: "F8:4E:17:CB:22:59"
        }
    ]

    property string btConnectingMac: ""
    property string btConnectingName: ""
    property string btStatusText: ""
    property string btStatusMac: ""
    property bool btAutoSwitchOnConnect: false
    readonly property string btBackendScriptPath: Qt.resolvedUrl("../bluetooth_backend.py").toString().replace("file://", "")
    property string pendingSwitchMac: ""
    property int pendingSwitchAttempts: 0
    readonly property int btSwitchMaxAttempts: 60
    readonly property bool btBusy: btConnectProcess.running || pendingSwitchMac.length > 0

    readonly property var outputDevices: {
        return BluetoothUtils.buildOutputDevices(root.sinkNodes, root.bluetoothTargets);
    }

    function connectBluetoothDevice(targetName, mac) {
        if (root.btBusy)
            return;

        root.btConnectingMac = mac;
        root.btConnectingName = targetName;
        root.btStatusMac = mac;
        root.btAutoSwitchOnConnect = true;
        root.btStatusText = "Starte Bluetooth-Backend...";
        btConnectProcess.targetMac = mac;
        btConnectProcess.running = true;
    }

    function finishBluetoothStatus(statusText) {
        root.btStatusText = statusText;
        btStatusClearTimer.restart();
    }

    function statusTextForBackendCode(code) {
        switch (code) {
        case "CHECK_BACKEND":
            return "Prüfe Bluetooth-Backend...";
        case "POWER_ON":
            return "Aktiviere Bluetooth...";
        case "CONNECT_DEVICE":
            return "Verbinde mit Gerät...";
        default:
            return code;
        }
    }

    property bool outputExpanded: false

    Process {
        id: btConnectProcess
        running: false
        property string targetMac: ""

        command: ["python3", root.btBackendScriptPath, "connect", targetMac]

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line.indexOf("STATUS:") === 0) {
                    root.btStatusText = root.statusTextForBackendCode(line.substring(7));
                    return;
                }

                if (line === "RESULT:OK") {
                    root.pendingSwitchMac = btConnectProcess.targetMac;
                    root.pendingSwitchAttempts = 0;
                    root.btStatusText = "Warte auf Audio-Ausgang...";
                    btSwitchTimer.start();
                    return;
                }

                if (line === "RESULT:FAIL") {
                    root.pendingSwitchMac = "";
                    btSwitchTimer.stop();
                    root.finishBluetoothStatus("Bluetooth-Verbindung fehlgeschlagen");
                    root.btConnectingMac = "";
                    root.btAutoSwitchOnConnect = false;
                    return;
                }

                if (line === "RESULT:BACKEND_UNAVAILABLE") {
                    root.pendingSwitchMac = "";
                    btSwitchTimer.stop();
                    root.finishBluetoothStatus("Bluetooth-Backend ist nicht verfuegbar");
                    root.btConnectingMac = "";
                    root.btAutoSwitchOnConnect = false;
                }
            }
        }
    }

    Timer {
        id: btSwitchTimer
        interval: 300 // ms per retry (~18s total with btSwitchMaxAttempts=60)
        repeat: true
        running: false
        onTriggered: {
            if (!root.pendingSwitchMac.length) {
                btSwitchTimer.stop();
                return;
            }

            root.pendingSwitchAttempts++;
            const sink = BluetoothUtils.findSinkByBluetooth(Pipewire.nodes.values, root.pendingSwitchMac, root.btConnectingName);
            if (sink) {
                // Bluetooth device is finally ready to be switched to. Do it (if still desired), and stop the timer and pending state.
                const shouldAutoSwitch = root.btAutoSwitchOnConnect;
                if (shouldAutoSwitch)
                    Pipewire.preferredDefaultAudioSink = sink;
                root.pendingSwitchMac = "";
                root.btConnectingMac = "";
                root.btAutoSwitchOnConnect = false;
                btSwitchTimer.stop();
                root.finishBluetoothStatus(shouldAutoSwitch ? "Verbunden" : "Verbunden im Hintergrund");
                return;
            }

            if (root.pendingSwitchAttempts >= root.btSwitchMaxAttempts) {
                root.pendingSwitchMac = "";
                root.btConnectingMac = "";
                root.btAutoSwitchOnConnect = false;
                btSwitchTimer.stop();
                root.finishBluetoothStatus("Verbunden, aber kein Audio-Ausgang gefunden");
            }
        }
    }

    Timer {
        id: btStatusClearTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (!root.btBusy) {
                root.btStatusText = "";
                root.btStatusMac = "";
            }
        }
    }

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
                        model: root.outputDevices

                        Item {
                            id: sinkDelegate
                            required property var modelData
                            width: parent ? parent.width : 0
                            readonly property bool hasBtStatus: modelData.isBluetooth && modelData.mac.length > 0 && (modelData.mac === root.btStatusMac) && root.btStatusText.length > 0
                            height: hasBtStatus ? 46 : 32

                            readonly property bool isSinkEntry: modelData.type === "sink"
                            readonly property bool isDefault: isSinkEntry && modelData.node.id === (Pipewire.defaultAudioSink?.id ?? -1)
                            readonly property bool isBusyTarget: root.btBusy && modelData.isBluetooth && (modelData.mac === root.btConnectingMac)

                            scale: sinkTap.pressed ? 0.97 : 1.0
                            SquishBehavior on scale {}

                            Rectangle {
                                anchors.fill: parent
                                radius: Spacing.spacing8
                                color: sinkDelegate.isDefault ? Qt.rgba(1, 1, 1, 0.06) : sinkTap.pressed ? Colors.hoverItemPressed : sinkHover.hovered ? Colors.hoverItemHovered : "transparent"
                                border.color: sinkDelegate.isDefault ? Colors.accentColor : sinkHover.hovered || sinkTap.pressed ? Colors.pillBorder : "transparent"
                            }

                            Item {
                                anchors {
                                    left: parent.left
                                    leftMargin: Spacing.spacing8
                                    right: parent.right
                                    rightMargin: Spacing.spacing8
                                    verticalCenter: parent.verticalCenter
                                }
                                height: parent.height

                                Row {
                                    id: rightStatusIcons
                                    anchors {
                                        right: parent.right
                                        verticalCenter: parent.verticalCenter
                                    }
                                    spacing: Spacing.spacing8

                                    TintedIcon {
                                        id: checkIcon
                                        source: "../icons/icons8-done.svg"
                                        size: Typography.fontSize12
                                        color: Colors.accentColor
                                        visible: sinkDelegate.isDefault && !sinkDelegate.isBusyTarget
                                        width: visible ? Typography.fontSize12 : 0
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    TintedIcon {
                                        id: busyIcon
                                        source: "../icons/icons8-spinner.svg"
                                        size: Typography.fontSize12
                                        color: Colors.textColorMuted
                                        visible: sinkDelegate.isBusyTarget
                                        width: visible ? Typography.fontSize12 : 0
                                        rotation: 0
                                        anchors.verticalCenter: parent.verticalCenter

                                        NumberAnimation on rotation {
                                            from: 0
                                            to: 360
                                            duration: 900
                                            loops: Animation.Infinite
                                            running: busyIcon.visible
                                            easing.type: Easing.Linear
                                        }
                                    }
                                }

                                Column {
                                    id: textBlock
                                    anchors {
                                        left: parent.left
                                        right: rightStatusIcons.left
                                        rightMargin: Spacing.spacing8
                                        verticalCenter: parent.verticalCenter
                                    }
                                    spacing: Spacing.spacing2

                                    Row {
                                        id: nameWithBluetooth
                                        width: parent.width
                                        spacing: Spacing.spacing4

                                        Label {
                                            id: deviceNameLabel
                                            text: sinkDelegate.modelData.name
                                            font.pixelSize: Typography.fontSize12
                                            font.weight: sinkDelegate.isDefault ? Font.Bold : Font.Normal
                                            color: sinkDelegate.isDefault ? Colors.accentColor : Colors.textColor
                                            elide: Text.ElideRight
                                            width: Math.min(implicitWidth, nameWithBluetooth.width - (bluetoothIcon.visible ? bluetoothIcon.width + nameWithBluetooth.spacing : 0))
                                        }

                                        TintedIcon {
                                            id: bluetoothIcon
                                            source: "../icons/icons8-bluetooth.svg"
                                            size: Typography.fontSize12
                                            color: sinkDelegate.isDefault ? Colors.accentColor : Colors.textColorMuted
                                            visible: sinkDelegate.modelData.isBluetooth
                                            width: visible ? Typography.fontSize12 : 0
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Label {
                                        visible: sinkDelegate.hasBtStatus
                                        width: parent.width
                                        text: root.btStatusText
                                        font.pixelSize: Typography.fontSize12
                                        font.weight: Font.Normal
                                        color: Colors.textColorMuted
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            HoverHandler {
                                id: sinkHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                id: sinkTap
                                enabled: sinkDelegate.isSinkEntry || !root.btBusy
                                onTapped: {
                                    if (sinkDelegate.isSinkEntry) {
                                        if (root.btBusy)
                                            root.btAutoSwitchOnConnect = false;
                                        Pipewire.preferredDefaultAudioSink = sinkDelegate.modelData.node;
                                        return;
                                    }

                                    root.connectBluetoothDevice(sinkDelegate.modelData.name, sinkDelegate.modelData.mac);
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
