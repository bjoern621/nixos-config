import QtQuick
import "../"
import "../base"

Row {
    id: datetime
    property var germanLocale: Qt.locale("de_DE")
    readonly property var currentDate: Clock.date

    anchors.verticalCenter: parent.verticalCenter
    spacing: Spacing.spacing8

    Row {
        spacing: Spacing.spacing4

        TintedIcon {
            source: "../icons/icons8-calendar-" + datetime.currentDate.getDate() + "-50.svg"
            size: Typography.fontSize20
            anchors.verticalCenter: parent.verticalCenter
        }

        Label {
            text: datetime.germanLocale.dayName(datetime.currentDate.getDay(), Locale.LongFormat) + ", " + datetime.currentDate.toLocaleDateString(datetime.germanLocale, "dd. MMM")
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Label {
        text: "\u00b7"
    }

    Row {
        spacing: Spacing.spacing4

        TintedIcon {
            source: "../icons/icons8-clock.svg"
            size: Typography.fontSize20
            anchors.verticalCenter: parent.verticalCenter
        }

        Label {
            text: Qt.formatDateTime(datetime.currentDate, "HH:mm")
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
