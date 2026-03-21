import QtQuick

Item {
    id: root

    property int displayYear: new Date().getFullYear()
    readonly property int _slideOffset: 40

    function navigateYear(direction) {
        slideInAnimation.stop()
        root.displayYear += direction
        monthGrid.x = direction * root._slideOffset
        monthGrid.opacity = 0
        slideInAnimation.start()
    }

    readonly property var today: new Date()
    readonly property int todayYear: today.getFullYear()
    readonly property int todayMonth: today.getMonth()
    readonly property int todayDay: today.getDate()
    readonly property var germanLocale: Qt.locale("de_DE")

    readonly property int dayCellSize: 24
    readonly property int weekNumberColumnWidth: 24
    readonly property int monthWidth: weekNumberColumnWidth + 7 * dayCellSize
    readonly property int monthHorizontalGap: 12
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
        radius: Spacing.spacing8
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

                Item {
                    width: 28
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter

                    property bool hovered: prevYearMouse.containsMouse

                    Rectangle {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        radius: 12
                        color: parent.hovered ? Colors.hoverItemHovered : "transparent"
                        border.color: parent.hovered ? Colors.pillBorder : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf053"
                        font.family: Typography.iconFontFamily
                        font.pixelSize: Typography.fontSize14
                        color: Colors.textColor
                    }

                    MouseArea {
                        id: prevYearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigateYear(-1)
                    }
                }

                Label {
                    text: root.displayYear
                    font.pixelSize: Typography.fontSize16
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: 28
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter

                    property bool hovered: nextYearMouse.containsMouse

                    Rectangle {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        radius: 12
                        color: parent.hovered ? Colors.hoverItemHovered : "transparent"
                        border.color: parent.hovered ? Colors.pillBorder : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf054"
                        font.family: Typography.iconFontFamily
                        font.pixelSize: Typography.fontSize14
                        color: Colors.textColor
                    }

                    MouseArea {
                        id: nextYearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigateYear(1)
                    }
                }
            }

            Item {
                id: gridClip
                clip: true
                width: monthGrid.implicitWidth
                height: monthGrid.implicitHeight

                Grid {
                    id: monthGrid
                    columns: 4
                    columnSpacing: root.monthHorizontalGap
                    rowSpacing: root.monthVerticalGap

                    ParallelAnimation {
                        id: slideInAnimation
                        NumberAnimation {
                            target: monthGrid
                            property: "x"
                            to: 0
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: monthGrid
                            property: "opacity"
                            to: 1
                            duration: 200
                            easing.type: Easing.OutQuad
                        }
                    }

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

                                        property bool hovered: dayCellMouse.containsMouse && dayCell.isValidDay

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: root.dayCellSize
                                            height: root.dayCellSize
                                            radius: (root.dayCellSize) / 2
                                            color: dayCell.isToday ? '#d5071b' : dayCell.hovered ? Colors.hoverItemHovered : "transparent"
                                            border.color: dayCell.hovered ? Colors.pillBorder : "transparent"
                                        }

                                        Label {
                                            anchors.fill: parent
                                            text: dayCell.isValidDay ? dayCell.dayNumber : ""
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        MouseArea {
                                            id: dayCellMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
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
}
