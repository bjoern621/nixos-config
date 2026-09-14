import QtQuick
import "../"
import "../base"

// Events of the selected day, beside the calendar grid and separate from it.
// Card and tokens follow CalendarMenu; only the content differs.
//
// Height computed from the model.
// Content sized off this panel loops a measured height,
// and the swap changes it at the slide midpoint anyway.
PopReveal {
    id: root

    // "YYYY-MM-DD" as CalendarService keys its days. Empty hides the panel.
    required property string dateKey
    // Height budget: the months block this panel centres on.
    required property int maxContentHeight

    showing: root.dateKey !== ""
    edge: Qt.LeftEdge

    // Menu closes on pointer-out, and the pointer crosses this panel to reach it.
    // Host feeds this back as HoverMenu.contentInteracting.
    readonly property bool hovered: panelHover.hovered

    HoverHandler {
        id: panelHover
    }

    // Day the content shows. Trails dateKey while a slide runs, and holds through the
    // hide, so fading out keeps the list it was showing instead of flashing the empty state.
    property string _shownKey: ""
    // Day the running slide swaps in. Empty while no slide runs.
    property string _pendingKey: ""
    // Day the panel is heading to.
    // Direction compares against it, since _shownKey trails an in-flight slide.
    readonly property string _targetKey: root._pendingKey !== "" ? root._pendingKey : root._shownKey
    // Whether a day was up before this change.
    // A day landing on a hidden panel rides the reveal, so its content takes the card
    // straight and only a day-to-day change slides.
    property bool _wasShowing: false
    onDateKeyChanged: {
        const opening = !root._wasShowing;
        root._wasShowing = root.dateKey !== "";

        if (root.dateKey === "" || root.dateKey === root._targetKey)
            return;

        if (opening) {
            slide.reset();
            root._pendingKey = "";
            root._shownKey = root.dateKey;
            return;
        }

        // "YYYY-MM-DD" orders lexically. Later day enters from the right.
        const direction = root.dateKey > root._targetKey ? 1 : -1;
        root._pendingKey = root.dateKey;
        slide.transition(direction);
    }

    readonly property var germanLocale: Qt.locale("de_DE")
    readonly property int contentPadding: Spacing.spacing12
    readonly property int panelWidth: 280

    readonly property var entries: CalendarService.eventsOn(root._shownKey)

    FontMetrics {
        id: rowMetrics
        font {
            family: Typography.fontFamily
            pixelSize: Typography.fontSize14
        }
    }

    readonly property int rowHeight: Math.ceil(rowMetrics.height) + Spacing.spacing4
    readonly property int headerHeight: Math.ceil(rowMetrics.height) + Spacing.spacing8

    // Empty day still holds one row, for the empty state.
    readonly property int _rows: Math.max(1, root.entries.length)
    readonly property int _listBudget: Math.max(rowHeight, root.maxContentHeight - headerHeight - 2 * contentPadding - Shape.shadowOffset)
    readonly property int listHeight: Math.min(_rows * rowHeight, _listBudget)

    readonly property int contentWidth: panelWidth - 2 * contentPadding
    implicitWidth: panelWidth + Shape.shadowOffset
    implicitHeight: headerHeight + listHeight + 2 * contentPadding + Shape.shadowOffset

    function _headerText(key) {
        if (!key)
            return "";
        const parts = key.split("-");
        const day = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        return day.toLocaleDateString(root.germanLocale, "dddd, dd. MMMM");
    }

    Card {
        anchors.fill: parent

        ContentSlide {
            id: slide

            onReadyToSwap: {
                root._shownKey = root._pendingKey;
                root._pendingKey = "";
                slide.completeTransition();
            }

            x: root.contentPadding
            y: root.contentPadding
            width: root.contentWidth
            height: root.headerHeight + root.listHeight

            Column {
                width: parent.width
                spacing: 0

                Label {
                    width: parent.width
                    height: root.headerHeight
                    text: root._headerText(root._shownKey)
                    verticalAlignment: Text.AlignVCenter
                }

                ScrollView {
                    width: parent.width
                    height: root.listHeight

                    Repeater {
                        model: root.entries

                        DayEventRow {
                            required property var modelData
                            entry: modelData
                            height: root.rowHeight
                        }
                    }

                    Label {
                        visible: root.entries.length === 0
                        width: parent.width
                        height: root.rowHeight
                        text: "Keine Termine"
                        font.weight: Font.Normal
                        color: Colors.textColorMuted
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
