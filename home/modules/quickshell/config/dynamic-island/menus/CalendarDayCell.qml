import QtQuick
import "../"
import "../base"

// One day of the month grid: number, today fill, selection, event dots.
//
// Selection takes the reverse of today's fill.
// In neo the accent is today's fill,
// so an accent mark on a selected day reads as a faded today.
// Today selected keeps its own fill and takes an inset ring, both facts holding at once.
Item {
    id: root

    required property int cellSize
    required property int dayNumber
    required property bool isValidDay
    required property bool isToday
    required property bool isSelected
    // Calendar uids holding an event on this day, capped by the caller.
    required property var eventCalendars

    signal activated

    width: cellSize
    height: cellSize

    readonly property bool hovered: cellMouse.containsMouse && root.isValidDay
    // Selected on any day but today, where the fill flips and the number goes with it.
    readonly property bool reversed: root.isSelected && !root.isToday
    readonly property int cornerRadius: Shape.usesBlur ? height / 2 : NeoTokens.pillRadius
    // Neo outlines every mark in ink; classic leaves the dot flat.
    readonly property int dotBorder: Shape.usesBlur ? 0 : 1
    // Cell holds a two-digit number, so a dot stays a marker rather than a shape.
    // Border eats a pixel per side, so the dot grows by it and keeps its colour core.
    readonly property int dotSize: Math.max(3, Math.round(cellSize / 7)) + 2 * root.dotBorder

    // Neo: today = launcher selected row (accent + ink border).
    // Classic: today = round, vibrant red; hover round too.
    LauncherDelegateBg {
        active: root.isToday
        hovered: root.hovered
        cornerRadius: root.cornerRadius
        activeColor: Shape.usesBlur ? Colors.calendarToday : Colors.selectedBackground
    }

    // Opaque, so it covers the hover fill underneath.
    // Hover darkens it instead, else a click that would clear the day reads as dead.
    Rectangle {
        anchors.fill: parent
        visible: root.reversed
        radius: root.cornerRadius
        color: root.hovered ? Colors.calendarSelectedHovered : Colors.calendarSelected
    }

    // Inset by 1, so a ring never touches the next cell: day cells sit at spacing 0.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        visible: root.isSelected && root.isToday
        color: "transparent"
        radius: Math.max(0, root.cornerRadius - 1)
        border.width: 2
        border.color: Colors.calendarSelected
    }

    Label {
        anchors.fill: parent
        text: root.isValidDay ? root.dayNumber : ""
        color: root.reversed ? Colors.calendarSelectedText : Colors.textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // A fill runs under the dots and swallows them, so there they get their own plate.
    Rectangle {
        visible: root.eventCalendars.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: dotRow.width + 2
        height: dotRow.height + 1
        radius: height / 2
        color: root.reversed ? Colors.calendarSelectedText : root.isToday ? Colors.pillBackground : "transparent"

        Row {
            id: dotRow
            anchors.centerIn: parent
            spacing: 1

            Repeater {
                model: root.eventCalendars

                Rectangle {
                    required property var modelData

                    width: root.dotSize
                    height: root.dotSize
                    radius: height / 2
                    // A calendar naming no colour still marks its day.
                    color: CalendarService.calendarColor(modelData) || Colors.accentColor
                    border.width: root.dotBorder
                    border.color: Colors.pillBorder
                }
            }
        }
    }

    MouseArea {
        id: cellMouse
        anchors.fill: parent
        hoverEnabled: true
        // Hand marks the cell as clickable. No squish: 365 cells at 20px read as jitter.
        acceptedButtons: root.isValidDay ? Qt.LeftButton : Qt.NoButton
        cursorShape: root.isValidDay ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
    }
}
