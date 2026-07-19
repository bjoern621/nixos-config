import QtQuick
import "../"

// Battery detail menu. Theme-aware: Card gives neo offset shadow + ink border.
// Pure display; all reads/formatting live in BatteryController.
Item {
    id: root

    readonly property int contentPadding: Spacing.spacing12

    // Grow by shadowOffset: Card draws neo shadow inside bottom-right (0 in classic).
    implicitWidth: 200 + Shape.shadowOffset
    implicitHeight: layout.height + 2 * contentPadding + Shape.shadowOffset

    BatteryController {
        id: controller
    }

    Card {
        anchors.fill: parent

        Column {
            id: layout
            x: root.contentPadding
            y: root.contentPadding
            width: parent.width - 2 * root.contentPadding
            spacing: Spacing.spacing6

            Label {
                text: controller.statusText
                font.pixelSize: Typography.fontSize14
            }

            // Time remaining
            Item {
                visible: controller.isDischarging && controller.dev.timeToEmpty > 0
                width: parent.width
                height: timeLeftKey.implicitHeight
                Label {
                    id: timeLeftKey
                    text: "Restzeit"
                    color: Colors.textColorMuted
                    font.weight: Font.Normal
                    anchors.left: parent.left
                }
                Label {
                    text: controller.formatTime(controller.dev.timeToEmpty)
                    font.weight: Font.Normal
                    anchors.right: parent.right
                }
            }

            Item {
                visible: controller.isCharging && controller.dev.timeToFull > 0
                width: parent.width
                height: timeFullKey.implicitHeight
                Label {
                    id: timeFullKey
                    text: "Voll in"
                    color: Colors.textColorMuted
                    font.weight: Font.Normal
                    anchors.left: parent.left
                }
                Label {
                    text: controller.formatTime(controller.dev.timeToFull)
                    font.weight: Font.Normal
                    anchors.right: parent.right
                }
            }

            // Power draw / charge
            Item {
                visible: controller.hasPowerFlow
                width: parent.width
                height: powerKey.implicitHeight
                Label {
                    id: powerKey
                    text: "Leistung"
                    color: Colors.textColorMuted
                    font.weight: Font.Normal
                    anchors.left: parent.left
                }
                Label {
                    text: controller.formatPower()
                    font.weight: Font.Normal
                    anchors.right: parent.right
                }
            }

            // Energy
            Item {
                width: parent.width
                height: energyKey.implicitHeight
                Label {
                    id: energyKey
                    text: "Energie"
                    color: Colors.textColorMuted
                    font.weight: Font.Normal
                    anchors.left: parent.left
                }
                Label {
                    text: controller.formatEnergy()
                    font.weight: Font.Normal
                    anchors.right: parent.right
                }
            }

            // Health
            Item {
                visible: controller.dev.healthSupported
                width: parent.width
                height: healthKey.implicitHeight
                Label {
                    id: healthKey
                    text: "Zustand"
                    color: Colors.textColorMuted
                    font.weight: Font.Normal
                    anchors.left: parent.left
                }
                Label {
                    text: controller.formatHealth()
                    font.weight: Font.Normal
                    anchors.right: parent.right
                }
            }
        }
    }
}
