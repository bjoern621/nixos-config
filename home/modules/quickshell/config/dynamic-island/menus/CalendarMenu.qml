import QtQuick
import "../"
import "../base"

// Theme-aware calendar grid. One view: neo/classic differ only in tokens and Card,
// not layout, so a split view would duplicate the whole grid. Logic in the controller.
Item {
    id: root

    // True while this screen's calendar popup is open; gates the weather scene animation.
    property bool weatherActive: false

    CalendarController {
        id: controller
    }

    // Height budget from host window. 0 = unbounded.
    property int maxHeight: 0

    // Menu height at day cell size `cell`, from constants and font metrics.
    // Six week rows per month, the most any month takes, so one year of the grid stands
    // as tall as the next and a reader of this size waits for no layout pass.
    // 4 * contentPadding = 2 layout gaps + top/bottom padding.
    function _heightFor(cell) {
        const gridW = 4 * 8 * cell + 3 * monthHorizontalGap;
        const monthCol = Math.ceil(monthLabelMetrics.height) + 7 * cell + 7 * Spacing.spacing2;
        const grid = 3 * monthCol + 2 * monthVerticalGap;
        const nav = 28 + Shape.buttonShadowOffset;
        return weather.predictedHeight(gridW) + nav + grid + 4 * contentPadding + Shape.shadowOffset;
    }

    // Compact when the normal layout would overflow the budget: smaller day
    // cells shrink the grid and, via width, the weather scene.
    readonly property bool compact: maxHeight > 0 && _heightFor(24) > maxHeight

    // Month label line height for _heightFor; Label defaults.
    FontMetrics {
        id: monthLabelMetrics
        font { family: Typography.fontFamily; pixelSize: Typography.fontSize14; weight: Font.Bold }
    }

    readonly property int dayCellSize: compact ? 20 : 24
    readonly property int weekNumberColumnWidth: dayCellSize
    readonly property int monthWidth: weekNumberColumnWidth + 7 * dayCellSize
    readonly property int monthHorizontalGap: Spacing.spacing12
    readonly property int monthVerticalGap: Spacing.spacing12
    readonly property int contentPadding: Spacing.spacing12

    // Month grid spans the full content; weather band matches it.
    readonly property int gridWidth: 4 * monthWidth + 3 * monthHorizontalGap

    // Card paper holds the content; shadowOffset is extra gutter for the neo shadow
    // (classic shadowOffset=0). implicitSize carries it so Bar sizes the menu to fit.
    readonly property int contentWidth: gridWidth + 2 * contentPadding
    implicitWidth: contentWidth + Shape.shadowOffset
    implicitHeight: _heightFor(dayCellSize)

    Card {
        anchors.fill: parent

        Column {
            id: layout
            x: root.contentPadding
            y: root.contentPadding
            spacing: root.contentPadding

            WeatherWidget {
                id: weather
                width: root.gridWidth
                active: root.weatherActive
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Spacing.spacing16

                StaticButton {
                    width: 28 + Shape.buttonShadowOffset
                    height: 28 + Shape.buttonShadowOffset
                    anchors.verticalCenter: parent.verticalCenter
                    centered: true
                    iconSource: "../icons/icons8-arrow-down.svg"
                    iconSize: Typography.fontSize14
                    iconRotation: 90
                    onClicked: root.navigateYear(-1)
                }

                StaticButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60 + Shape.buttonShadowOffset
                    height: 28 + Shape.buttonShadowOffset
                    // Jump back to today's year; inert while already there.
                    enabled: controller.displayYear !== controller.todayYear
                    centered: true
                    label: controller.displayYear
                    fontPixelSize: Typography.fontSize16
                    onClicked: root.navigateYear(controller.todayYear - controller.displayYear)
                }

                StaticButton {
                    width: 28 + Shape.buttonShadowOffset
                    height: 28 + Shape.buttonShadowOffset
                    anchors.verticalCenter: parent.verticalCenter
                    centered: true
                    iconSource: "../icons/icons8-arrow-down.svg"
                    iconSize: Typography.fontSize14
                    iconRotation: -90
                    onClicked: root.navigateYear(1)
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
