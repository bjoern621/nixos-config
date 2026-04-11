import Quickshell.Services.UPower
import QtQuick
import "../"
import "../base"

Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: Spacing.spacing4

    property string batteryIconSource: {
        if (UPower.displayDevice.state === UPowerDeviceState.Charging)
            return "../icons/icons8-battery-charging.svg";
        const pct = UPower.displayDevice.percentage;
        if (pct <= 0.25)
            return "../icons/icons8-battery-25.svg";
        if (pct <= 0.50)
            return "../icons/icons8-battery-50.svg";
        if (pct <= 0.75)
            return "../icons/icons8-battery-75.svg";
        return "../icons/icons8-battery-100.svg";
    }

    property color batteryColor: {
        const pct = UPower.displayDevice.percentage;
        if (pct <= 0.10)
            return Colors.batteryCritical;
        if (pct <= 0.25)
            return Colors.batteryWarning;
        return Colors.textColor;
    }

    TintedIcon {
        source: batteryIconSource
        size: Typography.fontSize20
        color: batteryColor
        anchors.verticalCenter: parent.verticalCenter
    }

    Label {
        text: Math.round(UPower.displayDevice.percentage * 100) + " %"
        anchors.verticalCenter: parent.verticalCenter
        color: batteryColor
    }
}
