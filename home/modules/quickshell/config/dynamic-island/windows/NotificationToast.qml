import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import "../"

// Notification toast stack – top-right corner, max 5 cards.
// Cards show with PopReveal, auto-dismiss after expireTimeout (default 5s).
// When >5 arrive, the oldest is instantly hidden.
Scope {
    id: toastScope

    readonly property int cardWidth: 340
    readonly property int sideMargin: Spacing.spacing16
    readonly property int topOffset: 52

    ListModel { id: notifModel }

    Connections {
        target: NotificationListener
        function onNotificationReceived(n) { toastScope._addEntry(n); }
    }

    function _addEntry(n) {
        if (notifModel.count >= 5)
            _hideEntry(notifModel.get(0).notifId);
        notifModel.append({
            notifId: n.id,
            appName: n.appName || "",
            summary: n.summary || "",
            body: n.body || "",
            active: true,
            notifObj: n
        });
    }

    function _hideEntry(notifId) {
        for (let i = 0; i < notifModel.count; i++) {
            if (notifModel.get(i).notifId === notifId) {
                notifModel.setProperty(i, "active", false);
                return;
            }
        }
    }

    function _removeEntry(notifId) {
        for (let i = 0; i < notifModel.count; i++) {
            if (notifModel.get(i).notifId === notifId) {
                const n = notifModel.get(i).notifObj;
                notifModel.remove(i);
                if (n && n.tracked) n.dismiss();
                return;
            }
        }
    }

    PanelWindow {
        visible: notifModel.count > 0

        anchors {
            top: true
            right: true
        }
        exclusiveZone: 0
        color: "transparent"

        implicitWidth: toastScope.cardWidth + toastScope.sideMargin * 2
        implicitHeight: toastScope.topOffset + notifColumn.implicitHeight + Spacing.spacing8

        mask: Region { item: notifColumn }

        Column {
            id: notifColumn
            x: toastScope.sideMargin
            y: toastScope.topOffset
            width: toastScope.cardWidth
            spacing: Spacing.spacing8

            Repeater {
                model: notifModel
                delegate: Item {
                    required property int notifId
                    required property string appName
                    required property string summary
                    required property string body
                    required property bool active
                    required property var notifObj

                    width: toastScope.cardWidth
                    height: cardReveal.height

                    PopReveal {
                        id: cardReveal
                        width: toastScope.cardWidth
                        height: card.implicitHeight
                        showing: active
                        slideOffset: Spacing.spacing12
                        showDuration: 80
                        hideDuration: 80
                        transformOriginValue: Item.TopRight

                        onHidden: {
                            if (!active) toastScope._removeEntry(notifId);
                        }

                        Timer {
                            interval: notifObj && notifObj.expireTimeout > 0
                                ? notifObj.expireTimeout * 1000
                                : 5000
                            running: active
                            onTriggered: toastScope._hideEntry(notifId)
                        }

                        Rectangle {
                            id: card
                            width: toastScope.cardWidth
                            implicitHeight: cardContent.implicitHeight + Spacing.spacing12 * 2
                            height: implicitHeight
                            color: cardTap.pressed ? Colors.hoverItemPressed
                                 : cardHover.hovered ? Colors.hoverItemHovered
                                 : Colors.pillBackground
                            border.width: 1
                            border.color: Colors.pillBorder
                            radius: Spacing.spacing8

                            scale: cardTap.pressed ? 0.97 : 1.0
                            SquishBehavior on scale {}

                            HoverHandler {
                                id: cardHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                id: cardTap
                                onTapped: toastScope._hideEntry(notifId)
                            }

                            Column {
                                id: cardContent
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    right: parent.right
                                    margins: Spacing.spacing12
                                }
                                spacing: Spacing.spacing4

                                Row {
                                    width: parent.width
                                    spacing: Spacing.spacing8

                                    Rectangle {
                                        width: 6
                                        height: 6
                                        radius: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: notifObj
                                            ? (notifObj.urgency === 2 ? Colors.batteryCritical
                                               : notifObj.urgency === 0 ? Colors.textColorMuted
                                               : Colors.accentColor)
                                            : Colors.accentColor
                                    }

                                    Text {
                                        text: appName
                                        font.family: Typography.fontFamily
                                        font.pixelSize: Typography.fontSize12
                                        font.weight: Font.Normal
                                        color: Colors.textColorMuted
                                        width: parent.width - 6 - parent.spacing
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    text: summary
                                    font.family: Typography.fontFamily
                                    font.pixelSize: Typography.fontSize14
                                    font.weight: Font.Bold
                                    color: Colors.textColor
                                    width: parent.width
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }

                                Text {
                                    text: body
                                    font.family: Typography.fontFamily
                                    font.pixelSize: Typography.fontSize12
                                    font.weight: Font.Normal
                                    color: Colors.textColorMuted
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
