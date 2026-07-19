pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import "../"

Scope {
    id: toastScope

    // Behavior only: model, expiry check, add/hide/remove, D-Bus.
    ToastController {
        id: controller
    }

    readonly property int cardWidth: 340
    readonly property int sideMargin: Spacing.spacing16
    readonly property int topOffset: 52
    readonly property int toastSlotReservedHeight: 120

    PanelWindow {
        visible: controller.model.count > 0

        anchors {
            top: true
            right: true
        }
        exclusiveZone: 0
        color: "transparent"

        implicitWidth: toastScope.cardWidth + toastScope.sideMargin * 2
        implicitHeight: toastScope.topOffset + controller.maxVisibleToasts * (toastScope.toastSlotReservedHeight + Spacing.spacing8) + Spacing.spacing8

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
                model: controller.model
                delegate: Item {
                    id: toastDelegate
                    required property string uid
                    required property string appName
                    required property string summary
                    required property string body
                    required property int urgency
                    required property real expireTimeout
                    required property bool active

                    readonly property var actions: controller.actionsFor(toastDelegate.uid)

                    // 0 keeps the toast up until it is dismissed by hand: either the
                    // client asked for no expiry, or the urgency is critical.
                    // expireTimeout is already milliseconds, matching what the client
                    // passed over D-Bus; -1 leaves the timeout up to this shell.
                    readonly property int expiryMs: {
                        if (toastDelegate.urgency === 2 || toastDelegate.expireTimeout === 0)
                            return 0;
                        return toastDelegate.expireTimeout > 0 ? Math.round(toastDelegate.expireTimeout) : 5000;
                    }

                    // Card body plus the neo shadow gutter below/right.
                    // Classic shadowOffset=0, so height matches the body exactly.
                    readonly property real cardBodyHeight: cardContent.implicitHeight + Spacing.spacing12 * 2
                    readonly property real fullHeight: cardBodyHeight + Shape.shadowOffset

                    width: toastScope.cardWidth
                    height: fullHeight
                    clip: true

                    NumberAnimation {
                        id: collapseAnim
                        target: toastDelegate
                        property: "height"
                        to: 0
                        duration: 150
                        easing.type: Easing.InCubic
                        onFinished: controller.removeEntry(toastDelegate.uid)
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
                        height: toastDelegate.fullHeight
                        onHidden: collapseAnim.start()

                        // Theme-aware card: classic glass, neo cream + ink + offset shadow.
                        Card {
                            id: card
                            width: toastScope.cardWidth
                            height: toastDelegate.fullHeight

                            scale: cardTap.pressed ? 0.97 : 1.0
                            SquishBehavior on scale {}

                            HoverHandler {
                                id: cardHover
                                cursorShape: controller.hasClickAction(toastDelegate.uid) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }

                            TapHandler {
                                id: cardTap
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: {
                                    if (controller.invokeDefault(toastDelegate.uid))
                                        controller.hideEntry(toastDelegate.uid);
                                }
                            }

                            // Drawn over the paper, under the text: hover tint.
                            Rectangle {
                                anchors.fill: parent
                                radius: card.radius
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
                                onExpired: controller.hideEntry(toastDelegate.uid)
                                onActionInvoked: index => {
                                    controller.invokeAction(toastDelegate.uid, index);
                                    controller.hideEntry(toastDelegate.uid);
                                }
                            }

                            Item {
                                id: closeBtn
                                anchors {
                                    right: parent.right
                                    rightMargin: Spacing.spacing8
                                    top: parent.top
                                    topMargin: Spacing.spacing8
                                }
                                width: Spacing.spacing24
                                height: Spacing.spacing24
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

                                // Close button bg. Classic round pill, neo cream hover + accent press.
                                ButtonBg {
                                    hovered: closeHover.hovered
                                    pressed: closeTap.pressed
                                }

                                HoverHandler {
                                    id: closeHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    id: closeTap
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    onTapped: {
                                        controller.dismiss(toastDelegate.uid);
                                        controller.hideEntry(toastDelegate.uid);
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
