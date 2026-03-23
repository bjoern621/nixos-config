import Quickshell.Services.UPower
import QtQuick
import "../"

Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: Spacing.spacing4

    property string batteryIcon: {
        const pct = UPower.displayDevice.percentage
        if (pct <= 0.05) return "\uf244"
        if (pct <= 0.35) return "\uf243"
        if (pct <= 0.60) return "\uf242"
        if (pct <= 0.85) return "\uf241"
        return "\uf240"
    }

    property color batteryColor: {
        const pct = UPower.displayDevice.percentage
        if (pct <= 0.10) return Colors.batteryCritical
        if (pct <= 0.25) return Colors.batteryWarning
        return Colors.textColor
    }

    Text {
        text: batteryIcon
        font.family: Typography.iconFontFamily
        font.pixelSize: Typography.fontSize14
        color: batteryColor
        anchors.verticalCenter: parent.verticalCenter
    }

    Label {
        text: Math.round(UPower.displayDevice.percentage * 100) + " %"
        anchors.verticalCenter: parent.verticalCenter
        color: batteryColor
    }
}
