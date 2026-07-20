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

    readonly property int contentPadding: Spacing.spacing12
    readonly property int baseWidth: 340

    implicitWidth: baseWidth + Shape.shadowOffset
    implicitHeight: mainLayout.height + 2 * contentPadding + Shape.shadowOffset

    onPasswordActiveChanged: if (passwordActive) pwCapture.forceActiveFocus()

    function resetState() {
        pendingSsid = "";
        passwordText = "";
        expandedSsid = "";
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
                            if (NetworkService.ethernetActive)
                                return "Kabel · " + NetworkService.ethernet.name;
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
            Item {
                visible: NetworkService.ethernetActive
                width: parent.width
                height: visible ? 40 : 0

                LauncherDelegateBg {
                    active: true
                }
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: Spacing.spacing8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Label {
                        text: "Kabelverbindung"
                        font.weight: Font.Bold
                    }
                    Label {
                        text: NetworkService.ethernetActive ? NetworkService.ethernet.name : ""
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                    }
                }
                TintedIcon {
                    source: "../icons/icons8-done.svg"
                    size: Typography.fontSize14
                    color: Colors.textColor
                    anchors.right: parent.right
                    anchors.rightMargin: Spacing.spacing8
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // ---- VPN ----
            Rectangle {
                visible: NetworkService.vpnConnections.length > 0
                width: parent.width
                height: 1
                color: Colors.separatorColor
            }
            Label {
                visible: NetworkService.vpnConnections.length > 0
                text: "VPN & WireGuard"
                font.pixelSize: Typography.fontSize12
                font.weight: Font.Normal
                color: Colors.textColorMuted
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
