pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick
import "../"

Scope {
    id: toastScope

    readonly property int cardWidth: 340
    readonly property int sideMargin: Spacing.spacing16
    readonly property int topOffset: 52
    readonly property int maxVisibleToasts: 5
    readonly property int toastSlotHeight: 120

    ListModel {
        id: notifModel
    }

    Connections {
        target: NotificationListener
        function onNotificationReceived(n) {
            toastScope._addEntry(n);
        }
    }

    function _addEntry(n) {
        if (notifModel.count >= 5)
            _hideEntry(notifModel.get(0).notifId);
        notifModel.append({
            notifId: n.id,
            appName: n.appName || "",
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency ?? 1,
            expireTimeout: n.expireTimeout ?? -1,
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
                if (n && n.tracked)
                    n.dismiss();
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
        color: "green"

        implicitWidth: toastScope.cardWidth + toastScope.sideMargin * 2
        implicitHeight: toastScope.topOffset + toastScope.maxVisibleToasts * (toastScope.toastSlotHeight + Spacing.spacing8) + Spacing.spacing8

        mask: Region {
            item: notifColumn
        }

        Column {
            id: notifColumn
            anchors {
                top: parent.top
                topMargin: toastScope.topOffset
                right: parent.right
                rightMargin: toastScope.sideMargin
            }
            width: toastScope.cardWidth
            spacing: Spacing.spacing8

            Repeater {
                model: notifModel
                delegate: Item {
                    id: toastDelegate
                    required property int notifId
                    required property string appName
                    required property string summary
                    required property string body
                    required property int urgency
                    required property int expireTimeout
                    required property bool active

                    width: toastScope.cardWidth
                    height: card.implicitHeight
                    clip: true
                    opacity: 0

                    ParallelAnimation {
                        id: slideInAnim
                        NumberAnimation {
                            target: card
                            property: "x"
                            to: 0
                            duration: 2000
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: toastDelegate
                            property: "opacity"
                            to: 1
                            duration: 2000
                            easing.type: Easing.OutCubic
                        }
                    }

                    ParallelAnimation {
                        id: slideOutAnim
                        NumberAnimation {
                            target: card
                            property: "x"
                            to: toastScope.cardWidth + toastScope.sideMargin
                            duration: 2000
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            target: toastDelegate
                            property: "opacity"
                            to: 0
                            duration: 2000
                            easing.type: Easing.InCubic
                        }
                        onFinished: collapseAnim.start()
                    }

                    NumberAnimation {
                        id: collapseAnim
                        target: toastDelegate
                        property: "height"
                        to: 0
                        duration: 2000
                        easing.type: Easing.InCubic
                        onFinished: toastScope._removeEntry(toastDelegate.notifId)
                    }

                    Component.onCompleted: slideInAnim.start()

                    onActiveChanged: {
                        if (!active) {
                            slideInAnim.stop();
                            collapseAnim.stop();
                            slideOutAnim.start();
                        }
                    }

                    Timer {
                        interval: toastDelegate.expireTimeout > 0 ? toastDelegate.expireTimeout * 1000 : 5000
                        running: toastDelegate.active
                        onTriggered: toastScope._hideEntry(toastDelegate.notifId)
                    }

                    Rectangle {
                        id: card
                        x: toastScope.cardWidth + toastScope.sideMargin
                        width: toastScope.cardWidth
                        implicitHeight: cardContent.implicitHeight + Spacing.spacing12 * 2
                        height: implicitHeight
                        color: cardTap.pressed ? Colors.hoverItemPressed : cardHover.hovered ? Colors.hoverItemHovered : Colors.pillBackground
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
                            onTapped: toastScope._hideEntry(toastDelegate.notifId)
                        }

                        Rectangle {
                            id: urgencyStripe
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                                leftMargin: Spacing.spacing8
                                topMargin: Spacing.spacing8
                                bottomMargin: Spacing.spacing8
                            }
                            width: 3
                            radius: 2
                            color: toastDelegate.urgency === 2 ? Colors.batteryCritical : Colors.textColorMuted
                        }

                        Column {
                            id: cardContent
                            anchors {
                                top: parent.top
                                topMargin: Spacing.spacing12
                                left: urgencyStripe.right
                                leftMargin: Spacing.spacing8
                                right: parent.right
                                rightMargin: Spacing.spacing12
                            }
                            spacing: Spacing.spacing4

                            Text {
                                text: toastDelegate.appName
                                font.family: Typography.fontFamily
                                font.pixelSize: Typography.fontSize12
                                font.weight: Font.Normal
                                color: Colors.textColorMuted
                                width: parent.width
                                elide: Text.ElideRight
                            }

                            Label {
                                text: toastDelegate.summary
                                width: parent.width
                                elide: Text.ElideRight
                                visible: text !== ""
                            }

                            Text {
                                text: toastDelegate.body
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
