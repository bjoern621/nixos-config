import Quickshell.Services.UPower
import QtQuick

Item {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool isCharging: dev.state === UPowerDeviceState.Charging
    readonly property bool isDischarging: dev.state === UPowerDeviceState.Discharging
    readonly property bool isFullyCharged: dev.state === UPowerDeviceState.FullyCharged

    readonly property int contentPadding: Spacing.spacing12

    implicitWidth: 200
    implicitHeight: layout.height + 2 * contentPadding

    function formatTime(seconds) {
        if (seconds <= 0) return "—"
        const h = Math.floor(seconds / 3600)
        const m = Math.floor((seconds % 3600) / 60)
        if (h > 0) return h + " Std " + m + " Min"
        return m + " Min"
    }

    Rectangle {
        anchors.fill: parent
        radius: Spacing.spacing12
        color: Colors.pillBackground
        border.width: 1
        border.color: Colors.pillBorder

        Column {
            id: layout
            x: root.contentPadding
            y: root.contentPadding
            width: parent.width - 2 * root.contentPadding
            spacing: Spacing.spacing6

            Label {
                text: root.isCharging ? "Wird geladen"
                    : root.isFullyCharged ? "Vollständig geladen"
                    : root.isDischarging ? "Wird entladen"
                    : "Unbekannt"
                font.pixelSize: Typography.fontSize14
            }

            // Time remaining
            Item {
                visible: root.isDischarging && root.dev.timeToEmpty > 0
                width: parent.width
                height: timeLeftKey.implicitHeight
                Label {
                    id: timeLeftKey
                    text: "Restzeit"
                    color: Colors.textColorMuted
                    font.weight: Font.Normal
                    anchors.left: parent.left
                }
                Label {
                    text: root.formatTime(root.dev.timeToEmpty)
                    font.weight: Font.Normal
                    anchors.right: parent.right
                }
            }

            Item {
                visible: root.isCharging && root.dev.timeToFull > 0
                width: parent.width
                height: timeFullKey.implicitHeight
                Label {
                    id: timeFullKey
                    text: "Voll in"
                    color: Colors.textColorMuted
                    font.weight: Font.Normal
                    anchors.left: parent.left
                }
                Label {
                    text: root.formatTime(root.dev.timeToFull)
                    font.weight: Font.Normal
                    anchors.right: parent.right
                }
            }

            // Power draw
            Item {
                visible: Math.abs(root.dev.changeRate) > 0
                width: parent.width
                height: powerKey.implicitHeight
                Label {
                    id: powerKey
                    text: "Leistung"
                    color: Colors.textColorMuted
                    font.weight: Font.Normal
                    anchors.left: parent.left
                }
                Label {
                    text: Math.abs(root.dev.changeRate).toFixed(1) + " W"
                    font.weight: Font.Normal
                    anchors.right: parent.right
                }
            }

            // Energy
            Item {
                width: parent.width
                height: energyKey.implicitHeight
                Label {
                    id: energyKey
                    text: "Energie"
                    color: Colors.textColorMuted
                    font.weight: Font.Normal
                    anchors.left: parent.left
                }
                Label {
                    text: root.dev.energy.toFixed(1) + " / " + root.dev.energyCapacity.toFixed(1) + " Wh"
                    font.weight: Font.Normal
                    anchors.right: parent.right
                }
            }

            // Health
            Item {
                visible: root.dev.healthSupported
                width: parent.width
                height: healthKey.implicitHeight
                Label {
                    id: healthKey
                    text: "Zustand"
                    color: Colors.textColorMuted
                    font.weight: Font.Normal
                    anchors.left: parent.left
                }
                Label {
                    text: Math.round(root.dev.healthPercentage * 100) + " %"
                    font.weight: Font.Normal
                    anchors.right: parent.right
                }
            }
        }
    }
}
