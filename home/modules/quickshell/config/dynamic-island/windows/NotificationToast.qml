pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import "../"

Scope {
    id: toastScope

    readonly property int cardWidth: 340
    readonly property int sideMargin: Spacing.spacing16
    readonly property int topOffset: 52
    readonly property int maxVisibleToasts: 5
    readonly property int toastSlotReservedHeight: 120

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
        if (Globals.doNotDisturb)
            return;
        if (notifModel.count >= 5)
            _hideEntryInstant(notifModel.get(0).notifId);

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

    function _hideEntryInstant(notifId) {
        for (let i = 0; i < notifModel.count; i++) {
            if (notifModel.get(i).notifId === notifId) {
                const n = notifModel.get(i).notifObj;
                notifModel.remove(i);
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
        color: "transparent"

        implicitWidth: toastScope.cardWidth + toastScope.sideMargin * 2
        implicitHeight: toastScope.topOffset + toastScope.maxVisibleToasts * (toastScope.toastSlotReservedHeight + Spacing.spacing8) + Spacing.spacing8

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

                    NumberAnimation {
                        id: collapseAnim
                        target: toastDelegate
                        property: "height"
                        to: 0
                        duration: 150
                        easing.type: Easing.InCubic
                        onFinished: toastScope._removeEntry(toastDelegate.notifId)
                    }

                    Component.onCompleted: popReveal.show()

                    onActiveChanged: {
                        if (!active)
                            popReveal.hide();
                    }

                    Timer {
                        interval: toastDelegate.expireTimeout > 0 ? toastDelegate.expireTimeout * 1000 : 5000
                        running: toastDelegate.active
                        onTriggered: toastScope._hideEntry(toastDelegate.notifId)
                    }

                    PopReveal {
                        id: popReveal
                        edge: Qt.RightEdge
                        showDuration: 250
                        hideDuration: 150
                        width: parent.width
                        height: card.implicitHeight
                        onHidden: collapseAnim.start()

                        Rectangle {
                            id: card
                            width: toastScope.cardWidth
                            implicitHeight: cardContent.implicitHeight + Spacing.spacing12 * 2
                            height: implicitHeight
                            color: Colors.pillBackground
                            border.width: 1
                            border.color: Colors.pillBorder
                            radius: Spacing.spacing8

                            NotificationContent {
                                id: cardContent
                                anchors {
                                    top: parent.top
                                    topMargin: Spacing.spacing12
                                    left: parent.left
                                    leftMargin: Spacing.spacing8
                                    right: parent.right
                                    rightMargin: Spacing.spacing12
                                }
                                appName: toastDelegate.appName
                                summary: toastDelegate.summary
                                body: toastDelegate.body
                                urgency: toastDelegate.urgency
                                expiryAnimationRunning: toastDelegate.active
                                expiryDuration: toastDelegate.expireTimeout > 0 ? toastDelegate.expireTimeout * 1000 : 5000
                            }
                        }
                    }
                }
            }
        }
    }
}
