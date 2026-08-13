pragma ComponentBehavior: Bound

import QtQuick
import "../"
import "../base"
import "../animations"

// Network dropdown: wifi list, ethernet, VPN, plus scan / airplane /
// settings. Binds to the NetworkService singleton; the view holds only the
// password-entry and expand state. Facade-adaptive, tuned for the neo theme.
Item {
    id: root

    // Drives the Bar's keyboard focus and the HoverMenu keepOpen.
    readonly property bool interactionActive: passwordActive
    readonly property bool passwordActive: pendingSsid.length > 0

    property string pendingSsid: ""
    property string passwordText: ""
    property string expandedSsid: ""
    property string expandedDevice: ""

    readonly property int contentPadding: Spacing.spacing12
    readonly property int baseWidth: 340

    implicitWidth: baseWidth + Shape.shadowOffset
    implicitHeight: mainLayout.height + 2 * contentPadding + Shape.shadowOffset

    onPasswordActiveChanged: if (passwordActive) pwCapture.forceActiveFocus()

    function resetState() {
        pendingSsid = "";
        passwordText = "";
        expandedSsid = "";
        expandedDevice = "";
    }

    // Connect / disconnect / prompt decision for a scanned network.
    function activate(net) {
        if (net.active) {
            NetworkService.disconnect(net.savedUuid.length ? net.savedUuid : net.ssid, net.ssid);
            return;
        }
        if (net.secured && !net.saved) {
            pendingSsid = net.ssid;
            passwordText = "";
            return;
        }
        NetworkService.connect(net.ssid, "", false);
    }

    function submitEntry() {
        NetworkService.connect(pendingSsid, passwordText, false);
        resetState();
    }

    Card {
        id: card
        anchors.fill: parent

        Column {
            id: mainLayout
            x: root.contentPadding
            y: root.contentPadding
            width: card.paperWidth - 2 * root.contentPadding
            spacing: Spacing.spacing8

            // ---- header ----
            Row {
                width: parent.width
                height: 36
                spacing: Spacing.spacing8

                Column {
                    width: parent.width - modeToggle.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Label {
                        text: "Netzwerk"
                        font.pixelSize: Typography.fontSize16
                    }
                    Label {
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        text: {
                            if (NetworkService.airplaneMode)
                                return "Flugmodus";
                            if (NetworkService.wiredConnectedCount > 1)
                                return "Kabel · " + NetworkService.wiredConnectedCount + " Verbindungen";
                            if (NetworkService.primaryWiredName.length)
                                return "Kabel · " + NetworkService.primaryWiredName;
                            if (NetworkService.activeSsid.length)
                                return "Verbunden · " + NetworkService.activeSsid + (NetworkService.vpnActive ? " · VPN" : "");
                            if (!NetworkService.wifiEnabled)
                                return "WLAN aus";
                            return "Nicht verbunden";
                        }
                    }
                }

                NetModeToggle {
                    id: modeToggle
                    anchors.verticalCenter: parent.verticalCenter
                    mode: NetworkService.radioMode
                    onSelected: m => NetworkService.setRadioMode(m)
                }
            }

            // ---- transient status ----
            Label {
                visible: NetworkService.statusText.length > 0
                width: parent.width
                text: NetworkService.statusText
                font.pixelSize: Typography.fontSize12
                font.weight: Font.Normal
                color: Colors.accentColor
                elide: Text.ElideRight
            }

            // ---- password entry ----
            Item {
                id: pwCapture
                visible: root.passwordActive
                width: parent.width
                height: visible ? pwColumn.height : 0
                focus: root.passwordActive

                Keys.onPressed: event => {
                    const k = event.key;
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    if (k === Qt.Key_Escape) {
                        root.resetState();
                    } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                        root.submitEntry();
                    } else if (k === Qt.Key_Backspace) {
                        root.passwordText = root.passwordText.slice(0, -1);
                    } else if (event.text && event.text.length > 0 && !ctrl) {
                        root.passwordText += event.text;
                    }
                    event.accepted = true;
                }

                Column {
                    id: pwColumn
                    width: parent.width
                    spacing: Spacing.spacing6

                    Label {
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        text: root.pendingSsid + " · Passwort"
                    }

                    Row {
                        width: parent.width
                        spacing: Spacing.spacing6

                        Rectangle {
                            id: pwField
                            width: parent.width - connectChip.width - cancelChip.width - 2 * parent.spacing
                            height: 32
                            radius: Shape.pill(height)
                            color: Colors.pillBackground
                            border.width: Shape.thinBorderWidth
                            border.color: Colors.accentColor
                            Label {
                                anchors.fill: parent
                                anchors.leftMargin: Spacing.spacing8
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                font.weight: Font.Normal
                                color: root.passwordText.length ? Colors.textColor : Colors.textColorMuted
                                text: root.passwordText.length ? "•".repeat(root.passwordText.length) : "Passwort"
                            }
                            TapHandler {
                                onTapped: pwCapture.forceActiveFocus()
                            }
                        }
                        NetChip {
                            id: connectChip
                            text: "Verbinden"
                            active: true
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: root.submitEntry()
                        }
                        NetChip {
                            id: cancelChip
                            text: "Abbrechen"
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: root.resetState()
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Colors.separatorColor
            }

            // ---- wifi list ----
            Row {
                width: parent.width
                spacing: Spacing.spacing6
                Label {
                    text: NetworkService.wifiEnabled ? "Verfügbare Netzwerke" : "WLAN ist deaktiviert"
                    font.pixelSize: Typography.fontSize12
                    font.weight: Font.Normal
                    color: Colors.textColorMuted
                    anchors.verticalCenter: parent.verticalCenter
                }
                TintedIcon {
                    id: scanSpinner
                    source: "../icons/icons8-spinner.svg"
                    size: Typography.fontSize12
                    color: Colors.textColorMuted
                    visible: NetworkService.scanning
                    anchors.verticalCenter: parent.verticalCenter
                    NumberAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: scanSpinner.visible
                        easing.type: Easing.Linear
                    }
                }
            }

            ScrollView {
                visible: NetworkService.wifiEnabled
                width: parent.width
                height: Math.min(implicitHeight, 300)

                Repeater {
                    model: NetworkService.wifiNetworks
                    NetworkRow {
                        required property var modelData
                        network: modelData
                        expanded: root.expandedSsid === modelData.ssid
                        onActivated: root.activate(modelData)
                        onDetailToggled: root.expandedSsid = (root.expandedSsid === modelData.ssid ? "" : modelData.ssid)
                    }
                }
            }

            // ---- ethernet ----
            // One row per wired device, present whether or not it carries a
            // connection, so a disconnected adapter still reports its link.
            Rectangle {
                visible: NetworkService.wiredConnections.length > 0
                width: parent.width
                height: 1
                color: Colors.separatorColor
            }
            Label {
                visible: NetworkService.wiredConnections.length > 0
                text: NetworkService.wiredConnections.length > 1 ? "Kabelverbindungen" : "Kabelverbindung"
                font.pixelSize: Typography.fontSize12
                font.weight: Font.Normal
                color: Colors.textColorMuted
            }
            Column {
                visible: NetworkService.wiredConnections.length > 0
                width: parent.width
                Repeater {
                    model: NetworkService.wiredConnections
                    EthernetRow {
                        required property var modelData
                        wired: modelData
                        expanded: root.expandedDevice === modelData.device
                        onDetailToggled: root.expandedDevice = (root.expandedDevice === modelData.device ? "" : modelData.device)
                    }
                }
            }

            // ---- VPN ----
            // Header carries the add button, so it stays put with no profiles;
            // otherwise the one entry point for creating the first VPN is hidden
            // exactly when it is needed.
            Rectangle {
                width: parent.width
                height: 1
                color: Colors.separatorColor
            }
            Item {
                width: parent.width
                height: addVpn.height

                Label {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "VPN"
                    font.pixelSize: Typography.fontSize12
                    font.weight: Font.Normal
                    color: Colors.textColorMuted
                }

                MiniIconButton {
                    id: addVpn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: NetworkService.addVpn()

                    // Plus drawn from two bars: recolors with the theme, no SVG.
                    Item {
                        anchors.centerIn: parent
                        width: Spacing.spacing12
                        height: Spacing.spacing12

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 2
                            radius: height / 2
                            color: Colors.textColorMuted
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 2
                            height: parent.height
                            radius: width / 2
                            color: Colors.textColorMuted
                        }
                    }
                }
            }
            Column {
                visible: NetworkService.vpnConnections.length > 0
                width: parent.width
                Repeater {
                    model: NetworkService.vpnConnections
                    VpnRow {
                        required property var modelData
                        vpn: modelData
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Colors.separatorColor
            }

            // ---- footer ----
            Flow {
                width: parent.width
                spacing: Spacing.spacing6

                NetChip {
                    text: "Einstellungen"
                    onClicked: NetworkService.openEditor()
                }
            }
        }
    }
}
