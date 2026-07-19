import QtQuick
import "../"
import "../base"

// Theme-aware calendar grid. One view: neo/classic differ only in tokens and Card,
// not layout, so a split view would duplicate the whole grid. Logic in the controller.
Item {
    id: root

    CalendarController {
        id: controller
    }

    readonly property int dayCellSize: 24
    readonly property int weekNumberColumnWidth: 24
    readonly property int monthWidth: weekNumberColumnWidth + 7 * dayCellSize
    readonly property int monthHorizontalGap: Spacing.spacing12
    readonly property int monthVerticalGap: Spacing.spacing12
    readonly property int contentPadding: Spacing.spacing12

    // Card paper holds the content; shadowOffset is extra gutter for the neo shadow
    // (classic shadowOffset=0). implicitSize carries it so Bar sizes the menu to fit.
    readonly property int contentWidth: 4 * monthWidth + 3 * monthHorizontalGap + 2 * contentPadding
    readonly property int contentHeight: layout.height + 2 * contentPadding
    implicitWidth: contentWidth + Shape.shadowOffset
    implicitHeight: contentHeight + Shape.shadowOffset

    Card {
        anchors.fill: parent

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

                    scale: prevYearMouse.pressed ? 0.85 : 1.0
                    SquishBehavior on scale {}

                    ButtonBg {
                        hovered: parent.hovered
                    }

                    TintedIcon {
                        anchors.centerIn: parent
                        source: "../icons/icons8-arrow-down.svg"
                        size: Typography.fontSize14
                        rotation: 90
                    }

                    MouseArea {
                        id: prevYearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigateYear(-1)
                    }
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: yearLabel.implicitWidth + 24
                    height: 28

                    property bool canNavigate: controller.displayYear !== controller.todayYear
                    property bool hovered: yearMouse.containsMouse && canNavigate

                    scale: yearMouse.pressed && canNavigate ? 0.85 : 1.0
                    SquishBehavior on scale {}

                    ButtonBg {
                        hovered: parent.hovered
                    }

                    Label {
                        id: yearLabel
                        anchors.centerIn: parent
                        text: controller.displayYear
                        font.pixelSize: Typography.fontSize16
                    }

                    MouseArea {
                        id: yearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent.canNavigate ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (parent.canNavigate) {
                                root.navigateYear(controller.todayYear - controller.displayYear);
                            }
                        }
                    }
                }

                Item {
                    width: 28
                    height: 28
                    anchors.verticalCenter: parent.verticalCenter

                    property bool hovered: nextYearMouse.containsMouse

                    scale: nextYearMouse.pressed ? 0.85 : 1.0
                    SquishBehavior on scale {}

                    ButtonBg {
                        hovered: parent.hovered
                    }

                    TintedIcon {
                        anchors.centerIn: parent
                        source: "../icons/icons8-arrow-down.svg"
                        size: Typography.fontSize14
                        rotation: -90
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

            ContentSlide {
                id: gridSlide

                onReadyToSwap: direction => {
                    controller.commitNavigate();
                    gridSlide.completeTransition();
                }

                Grid {
                    id: monthGrid
                    columns: 4
                    columnSpacing: root.monthHorizontalGap
                    rowSpacing: root.monthVerticalGap

                    Repeater {
                        model: 12

                        delegate: Column {
                            id: mCol

                            required property int index
                            property int monthIndex: index
                            property int daysInMonth: controller.getDaysInMonth(controller.displayYear, monthIndex)
                            property int firstDayOffset: controller.getFirstDayOffset(controller.displayYear, monthIndex)

                            width: root.monthWidth
                            spacing: Spacing.spacing2

                            Label {
                                text: controller.germanLocale.monthName(mCol.monthIndex, Locale.LongFormat)
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
                                                    return controller.getIsoWeekNumber(controller.displayYear, mCol.monthIndex, d);
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
                                            property bool isToday: isValidDay && controller.displayYear === controller.todayYear && mCol.monthIndex === controller.todayMonth && dayNumber === controller.todayDay

                                            width: root.dayCellSize
                                            height: root.dayCellSize

                                            property bool hovered: dayCellMouse.containsMouse && dayCell.isValidDay

                                            // Neo: today = launcher selected row (accent + ink border).
                                            // Classic: today = round, vibrant red; hover round too.
                                            LauncherDelegateBg {
                                                active: parent.isToday
                                                hovered: parent.hovered
                                                cornerRadius: Shape.usesBlur ? height / 2 : NeoTokens.pillRadius
                                                activeColor: Shape.usesBlur ? Colors.calendarToday : Colors.selectedBackground
                                            }

                                            Label {
                                                anchors.fill: parent
                                                text: dayCell.isValidDay ? dayCell.dayNumber : ""
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            // Days carry no action.
                                            // Hover highlight only, no pointing-hand cursor, no squish.
                                            MouseArea {
                                                id: dayCellMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.NoButton
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

    // View owns the ContentSlide; controller accumulates the year step.
    function navigateYear(direction) {
        controller.beginNavigate(direction);
        gridSlide.transition(direction > 0 ? 1 : -1);
    }
}
