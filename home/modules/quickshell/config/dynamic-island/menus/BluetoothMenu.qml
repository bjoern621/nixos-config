pragma ComponentBehavior: Bound

import QtQuick
import "../"
import "../base"
import "../animations"

// Bluetooth dropdown: power, paired devices with connect/battery/detail, plus
// scan / discovered devices / discoverable. Binds the BluetoothService singleton;
// the view holds only rename-entry and expand state. Facade-adaptive, neo-tuned.
Item {
    id: root

    // Drives the Bar's keyboard focus and the HoverMenu keepOpen.
    readonly property bool interactionActive: renameActive
    readonly property bool renameActive: renamingAddress.length > 0

    property string renamingAddress: ""
    property string renameOldName: ""
    property string renameText: ""
    property string expandedAddress: ""

    readonly property int contentPadding: Spacing.spacing12
    readonly property int baseWidth: 340

    implicitWidth: baseWidth + Shape.shadowOffset
    implicitHeight: mainLayout.height + 2 * contentPadding + Shape.shadowOffset

    onRenameActiveChanged: if (renameActive) renameCapture.forceActiveFocus()

    function resetState() {
        renamingAddress = "";
        renameOldName = "";
        renameText = "";
        expandedAddress = "";
    }

    function _deviceByAddress(addr) {
        const list = BluetoothService.devices;
        for (let i = 0; i < list.length; i++)
            if (list[i].address === addr)
                return list[i];
        return null;
    }

    function beginRename(device) {
        if (!device)
            return;
        renamingAddress = device.address;
        renameOldName = device.name;
        renameText = device.name;
        renameCapture.forceActiveFocus();
    }
    function submitRename() {
        const d = _deviceByAddress(renamingAddress);
        if (d)
            BluetoothService.rename(d, renameText);
        renamingAddress = "";
        renameOldName = "";
        renameText = "";
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
                    width: parent.width - powerToggle.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Label {
                        text: "Bluetooth"
                        font.pixelSize: Typography.fontSize16
                    }
                    Label {
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        text: BluetoothService.summary
                    }
                }

                NetToggle {
                    id: powerToggle
                    anchors.verticalCenter: parent.verticalCenter
                    checked: BluetoothService.powered
                    busy: BluetoothService.transitioning || BluetoothService.powerBusy
                    onToggled: BluetoothService.togglePowered()
                }
            }

            // ---- transient status ----
            Label {
                visible: BluetoothService.statusText.length > 0
                width: parent.width
                text: BluetoothService.statusText
                font.pixelSize: Typography.fontSize12
                font.weight: Font.Normal
                color: Colors.accentColor
                elide: Text.ElideRight
            }

            // ---- rename entry ----
            Item {
                id: renameCapture
                visible: root.renameActive
                width: parent.width
                height: visible ? renameColumn.height : 0
                focus: root.renameActive

                Keys.onPressed: event => {
                    const k = event.key;
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    if (k === Qt.Key_Escape) {
                        root.resetState();
                    } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                        root.submitRename();
                    } else if (k === Qt.Key_Backspace) {
                        root.renameText = root.renameText.slice(0, -1);
                    } else if (event.text && event.text.length > 0 && !ctrl) {
                        root.renameText += event.text;
                    }
                    event.accepted = true;
                }

                Column {
                    id: renameColumn
                    width: parent.width
                    spacing: Spacing.spacing6

                    Label {
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: Typography.fontSize12
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        text: "Umbenennen · " + root.renameOldName
                    }

                    Row {
                        width: parent.width
                        spacing: Spacing.spacing6

                        Rectangle {
                            width: parent.width - saveChip.width - cancelChip.width - 2 * parent.spacing
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
                                color: root.renameText.length ? Colors.textColor : Colors.textColorMuted
                                text: root.renameText.length ? root.renameText : "Neuer Name"
                            }
                            TapHandler {
                                onTapped: renameCapture.forceActiveFocus()
                            }
                        }
                        NetChip {
                            id: saveChip
                            text: "Speichern"
                            active: true
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: root.submitRename()
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

            // ---- no adapter ----
            Label {
                visible: !BluetoothService.hasAdapter
                width: parent.width
                text: "Kein Bluetooth-Adapter gefunden"
                font.pixelSize: Typography.fontSize12
                font.weight: Font.Normal
                color: Colors.textColorMuted
            }

            // ---- powered off ----
            Label {
                visible: BluetoothService.hasAdapter && !BluetoothService.powered
                width: parent.width
                text: "Bluetooth ist deaktiviert"
                font.pixelSize: Typography.fontSize12
                font.weight: Font.Normal
                color: Colors.textColorMuted
            }

            // ---- paired devices ----
            Label {
                visible: BluetoothService.powered
                width: parent.width
                text: "Meine Geräte"
                font.pixelSize: Typography.fontSize12
                font.weight: Font.Normal
                color: Colors.textColorMuted
            }

            Label {
                visible: BluetoothService.powered && BluetoothService.pairedDevices.length === 0
                width: parent.width
                text: "Keine gekoppelten Geräte"
                font.pixelSize: Typography.fontSize12
                font.weight: Font.Normal
                color: Colors.placeholder
            }

            ScrollView {
                visible: BluetoothService.powered && BluetoothService.pairedDevices.length > 0
                width: parent.width
                height: Math.min(implicitHeight, 300)

                Repeater {
                    model: BluetoothService.pairedDevices
                    BluetoothDeviceRow {
                        required property var modelData
                        device: modelData
                        expanded: root.expandedAddress === modelData.address
                        onActivated: BluetoothService.activate(modelData)
                        onDetailToggled: root.expandedAddress = (root.expandedAddress === modelData.address ? "" : modelData.address)
                        onRenameRequested: root.beginRename(modelData)
                    }
                }
            }

            // ---- discovered devices ----
            Rectangle {
                visible: BluetoothService.powered && (BluetoothService.discovering || BluetoothService.availableDevices.length > 0)
                width: parent.width
                height: 1
                color: Colors.separatorColor
            }
            Row {
                visible: BluetoothService.powered && (BluetoothService.discovering || BluetoothService.availableDevices.length > 0)
                width: parent.width
                spacing: Spacing.spacing6
                Label {
                    text: "Verfügbare Geräte"
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
                    visible: BluetoothService.discovering
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
                visible: BluetoothService.powered && BluetoothService.availableDevices.length > 0
                width: parent.width
                height: Math.min(implicitHeight, 176)

                Repeater {
                    model: BluetoothService.availableDevices
                    BluetoothDeviceRow {
                        required property var modelData
                        device: modelData
                        available: true
                        onActivated: BluetoothService.activate(modelData)
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
                    visible: BluetoothService.powered
                    text: "Sichtbar"
                    active: BluetoothService.discoverable
                    onClicked: BluetoothService.toggleDiscoverable()
                }
                NetChip {
                    text: "Einstellungen"
                    onClicked: BluetoothService.openSettings()
                }
            }
        }
    }
}
