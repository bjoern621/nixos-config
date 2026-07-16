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
        function onNotificationReceived(uid, notification) {
            toastScope._addEntry(uid, notification);
        }
        function onNotificationClosed(uid) {
            toastScope._hideEntry(uid);
        }
    }

    function _addEntry(uid, n) {
        if (Globals.doNotDisturb)
            return;
        if (notifModel.count >= toastScope.maxVisibleToasts)
            notifModel.remove(0);

        notifModel.append({
            uid: uid,
            appName: n.appName || "",
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency ?? 1,
            expireTimeout: n.expireTimeout ?? -1,
            active: true
        });
    }

    function _indexOf(uid) {
        for (let i = 0; i < notifModel.count; i++) {
            if (notifModel.get(i).uid === uid)
                return i;
        }
        return -1;
    }

    // Starts the hide animation. The delegate drops itself once it has played out.
    function _hideEntry(uid) {
        const i = _indexOf(uid);
        if (i >= 0)
            notifModel.setProperty(i, "active", false);
    }

    // Removes the toast only. The notification stays tracked so the notification
    // center keeps its actions until it is dismissed there.
    function _removeEntry(uid) {
        const i = _indexOf(uid);
        if (i >= 0)
            notifModel.remove(i);
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
                    required property string uid
                    required property string appName
                    required property string summary
                    required property string body
                    required property int urgency
                    required property real expireTimeout
                    required property bool active

                    readonly property var actions: NotificationListener.actionsFor(toastDelegate.uid)

                    // 0 keeps the toast up until it is dismissed by hand: either the
                    // client asked for no expiry, or the urgency is critical.
                    // expireTimeout is already milliseconds, matching what the client
                    // passed over D-Bus; -1 leaves the timeout up to this shell.
                    readonly property int expiryMs: {
                        if (toastDelegate.urgency === 2 || toastDelegate.expireTimeout === 0)
                            return 0;
                        return toastDelegate.expireTimeout > 0 ? Math.round(toastDelegate.expireTimeout) : 5000;
                    }

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
                        onFinished: toastScope._removeEntry(toastDelegate.uid)
                    }

                    Component.onCompleted: popReveal.show()

                    onActiveChanged: {
                        if (!active)
                            popReveal.hide();
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

                            scale: cardTap.pressed ? 0.97 : 1.0
                            SquishBehavior on scale {}

                            HoverHandler {
                                id: cardHover
                                cursorShape: NotificationListener.hasClickAction(toastDelegate.uid) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }

                            TapHandler {
                                id: cardTap
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: {
                                    if (NotificationListener.invokeDefault(toastDelegate.uid))
                                        toastScope._hideEntry(toastDelegate.uid);
                                }
                            }

                            // Drawn before the content so the hover tint sits over the
                            // card background but under the text.
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: cardTap.pressed ? Colors.hoverItemPressed : cardHover.hovered ? Colors.hoverItemHovered : "transparent"
                            }

                            NotificationContent {
                                id: cardContent
                                anchors {
                                    top: parent.top
                                    topMargin: Spacing.spacing12
                                    left: parent.left
                                    leftMargin: Spacing.spacing8
                                    right: parent.right
                                    // Keeps the text clear of the close button.
                                    rightMargin: Spacing.spacing12 + Spacing.spacing24
                                }
                                appName: toastDelegate.appName
                                summary: toastDelegate.summary
                                body: toastDelegate.body
                                urgency: toastDelegate.urgency
                                actions: toastDelegate.actions
                                expiryAnimationRunning: toastDelegate.active && toastDelegate.expiryMs > 0
                                expiryDuration: toastDelegate.expiryMs
                                expiryPaused: cardHover.hovered
                                onExpired: toastScope._hideEntry(toastDelegate.uid)
                                onActionInvoked: index => {
                                    NotificationListener.invokeAction(toastDelegate.uid, index);
                                    toastScope._hideEntry(toastDelegate.uid);
                                }
                            }

                            Rectangle {
                                id: closeBtn
                                anchors {
                                    right: parent.right
                                    rightMargin: Spacing.spacing8
                                    top: parent.top
                                    topMargin: Spacing.spacing8
                                }
                                width: Spacing.spacing24
                                height: Spacing.spacing24
                                radius: height / 2
                                color: closeTap.pressed ? Colors.hoverItemPressed : closeHover.hovered ? Colors.hoverItemHovered : "transparent"
                                border.width: 1
                                border.color: closeHover.hovered ? Colors.pillBorder : "transparent"
                                opacity: cardHover.hovered ? 1.0 : 0.0
                                // An item at zero opacity still takes input.
                                visible: closeBtn.opacity > 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 80
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                scale: closeTap.pressed ? 0.85 : 1.0
                                SquishBehavior on scale {}

                                HoverHandler {
                                    id: closeHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    id: closeTap
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    onTapped: {
                                        NotificationListener.dismiss(toastDelegate.uid);
                                        toastScope._hideEntry(toastDelegate.uid);
                                    }
                                }

                                TintedIcon {
                                    anchors.centerIn: parent
                                    size: Spacing.spacing12
                                    source: "../icons/icons8-close.svg"
                                    color: Colors.textColorMuted
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
