import QtQuick
import "../"
import "../base"

// One event in the day panel: calendar colour, start time, title.
// An all-day event leaves the time column empty, so every title keeps one indent.
Item {
    id: root

    required property var entry

    width: parent ? parent.width : 0

    readonly property int dotSize: 6
    // Widest "HH:mm" plus its gap.
    readonly property int timeWidth: 44

    Rectangle {
        id: dot
        width: root.dotSize
        height: root.dotSize
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        // A calendar naming no colour still marks its row.
        color: CalendarService.calendarColor(root.entry.calendar) || Colors.accentColor
    }

    Label {
        id: time
        anchors.verticalCenter: parent.verticalCenter
        x: dot.width + Spacing.spacing8
        width: root.timeWidth
        text: root.entry.allDay ? "" : root.entry.start
        font.weight: Font.Normal
        color: Colors.textColorMuted
    }

    Label {
        anchors.verticalCenter: parent.verticalCenter
        x: time.x + time.width
        width: Math.max(0, root.width - x)
        text: root.entry.summary
        elide: Text.ElideRight
    }
}
