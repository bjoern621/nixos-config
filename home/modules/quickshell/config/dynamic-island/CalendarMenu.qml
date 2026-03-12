import QtQuick

Item {
    id: root

    property int displayYear: new Date().getFullYear()

    readonly property var today: new Date()
    readonly property int todayYear: today.getFullYear()
    readonly property int todayMonth: today.getMonth()
    readonly property int todayDay: today.getDate()
    readonly property var germanLocale: Qt.locale("de_DE")

    readonly property int dayCellSize: 18
    readonly property int weekNumberColumnWidth: 24
    readonly property int monthWidth: weekNumberColumnWidth + 7 * dayCellSize
    readonly property int monthHorizontalGap: 10
    readonly property int monthVerticalGap: 12
    readonly property int contentPadding: 12

    implicitWidth: 4 * monthWidth + 3 * monthHorizontalGap + 2 * contentPadding
    implicitHeight: layout.height + 2 * contentPadding

    function getDaysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function getFirstDayOffset(year, month) {
        return (new Date(year, month, 1).getDay() + 6) % 7;
    }

    function getIsoWeekNumber(year, month, day) {
        var dt = new Date(year, month, day);
        dt.setHours(0, 0, 0, 0);
        dt.setDate(dt.getDate() + 3 - (dt.getDay() + 6) % 7);
        var y1 = new Date(dt.getFullYear(), 0, 4);
        return 1 + Math.round(((dt - y1) / 86400000 - 3 + (y1.getDay() + 6) % 7) / 7);
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Colors.pillBackground
        border.width: 1
        border.color: Colors.pillBorder

        Column {
            id: layout
            x: root.contentPadding
            y: root.contentPadding
            spacing: root.contentPadding

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Spacing.spacing16

                Text {
                    text: "\uf053"
                    font.family: Typography.iconFontFamily
                    font.pixelSize: Typography.fontSize14
                    color: Colors.textColor
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.displayYear--
                    }
                }

                Label {
                    text: root.displayYear
                    font.pixelSize: Typography.fontSize16
                }

                Text {
                    text: "\uf054"
                    font.family: Typography.iconFontFamily
                    font.pixelSize: Typography.fontSize14
                    color: Colors.textColor
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.displayYear++
                    }
                }
            }

            Grid {
                columns: 4
                columnSpacing: root.monthHorizontalGap
                rowSpacing: root.monthVerticalGap

                Repeater {
                    model: 12

                    delegate: Column {
                        id: mCol

                        required property int index
                        property int monthIndex: index
                        property int daysInMonth: root.getDaysInMonth(root.displayYear, monthIndex)
                        property int firstDayOffset: root.getFirstDayOffset(root.displayYear, monthIndex)

                        width: root.monthWidth
                        spacing: 2

                        Label {
                            text: root.germanLocale.monthName(mCol.monthIndex, Locale.LongFormat)
                            font.pixelSize: Typography.fontSize14
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Row {
                            spacing: 0

                            Rectangle {
                                width: root.weekNumberColumnWidth
                                height: root.dayCellSize
                                color: "transparent"
                            }

                            Repeater {
                                model: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

                                Text {
                                    required property string modelData

                                    width: root.dayCellSize
                                    height: root.dayCellSize
                                    text: modelData
                                    font {
                                        family: Typography.fontFamily
                                        pixelSize: Typography.fontSize12
                                        weight: Font.Bold
                                    }
                                    color: Colors.textColorMuted
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        Repeater {
                            model: 6

                            delegate: Row {
                                id: wRow

                                required property int index
                                property int weekIndex: index
                                property int firstDay: weekIndex * 7 - mCol.firstDayOffset + 1

                                visible: {
                                    for (var i = 0; i < 7; i++)
                                        if (firstDay + i >= 1 && firstDay + i <= mCol.daysInMonth)
                                            return true;
                                    return false;
                                }
                                spacing: 0

                                Text {
                                    width: root.weekNumberColumnWidth
                                    height: root.dayCellSize
                                    text: {
                                        for (var i = 0; i < 7; i++) {
                                            var d = wRow.firstDay + i;
                                            if (d >= 1 && d <= mCol.daysInMonth)
                                                return root.getIsoWeekNumber(root.displayYear, mCol.monthIndex, d);
                                        }
                                        return "";
                                    }
                                    font {
                                        family: Typography.fontFamily
                                        pixelSize: Typography.fontSize12
                                    }
                                    color: Colors.textColorMuted
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Repeater {
                                    model: 7

                                    delegate: Item {
                                        id: dayCell

                                        required property int index
                                        property int dayNumber: wRow.firstDay + index
                                        property bool isValidDay: dayNumber >= 1 && dayNumber <= mCol.daysInMonth
                                        property bool isToday: isValidDay
                                            && root.displayYear === root.todayYear
                                            && mCol.monthIndex === root.todayMonth
                                            && dayNumber === root.todayDay

                                        width: root.dayCellSize
                                        height: root.dayCellSize

                                        Text {
                                            anchors.centerIn: parent
                                            text: dayCell.isValidDay ? dayCell.dayNumber : ""
                                            font {
                                                family: Typography.fontFamily
                                                pixelSize: Typography.fontSize14
                                                weight: dayCell.isToday ? Font.Bold : Font.Normal
                                            }
                                            color: dayCell.isToday ? "#cc0000" : Colors.textColor
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: dayCell.isValidDay
                                            cursorShape: dayCell.isValidDay ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: console.log("Calendar: clicked " + dayCell.dayNumber + "." + (mCol.monthIndex + 1) + "." + root.displayYear)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
