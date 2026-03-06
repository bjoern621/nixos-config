import QtQuick

Label {
    id: clock
    property var germanLocale: Qt.locale("de_DE")
    property var currentDate: new Date()
    text: "\uf133 " + germanLocale.dayName(currentDate.getDay(), Locale.ShortFormat) + ", " + Qt.formatDateTime(currentDate, "dd.MM.yyyy \uf017 HH:mm")
    anchors.verticalCenter: parent.verticalCenter

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            clock.currentDate = new Date()
            clock.text = "\uf133 " + clock.germanLocale.dayName(clock.currentDate.getDay(), Locale.ShortFormat) + ", " + Qt.formatDateTime(clock.currentDate, "dd.MM.yyyy \uf017 HH:mm")
        }
    }
}
