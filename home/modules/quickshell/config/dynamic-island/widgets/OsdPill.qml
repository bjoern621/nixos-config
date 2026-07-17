import QtQuick
import "../"
import "../base"

// OSD pill: icon, label, value readout, progress bar.
// Shared by VolumeOsd and BrightnessOsd, which differ only in data.
Rectangle {
    id: root

    property url iconSource
    property string label: ""
    // 0-100.
    // Drives progress bar only.
    property int value: 0
    // Readout right of label.
    // Updates live, so scrolling through steps does not restart the swap animation.
    property string valueLabel: ""
    // Replaces valueLabel while muted.
    // Unused where muted stays false.
    property string mutedLabel: ""
    property bool muted: false
    property color fillColor: Colors.accentColor

    readonly property int marginTopBottom: Spacing.spacing8
    readonly property int marginLeftRight: Spacing.spacing12
    readonly property int iconSize: Typography.fontSize20
    readonly property int iconBox: root.iconSize + Spacing.spacing4
    readonly property int barHeight: Spacing.spacing6
    // Gap matches cap radius so both rounded ends stay flush.
    // Collapses at 0 and 100, where one segment is empty and the gap would show as a stub.
    readonly property int barGap: root.value > 0 && root.value < 100 ? root.barHeight / 2 : 0

    implicitHeight: contentRow.implicitHeight + 2 * root.marginTopBottom

    radius: root.implicitHeight / 2
    color: Colors.pillBackground
    border.width: 1
    border.color: Colors.pillBorder

    Row {
        id: contentRow
        anchors {
            fill: parent
            leftMargin: root.marginLeftRight
            rightMargin: root.marginLeftRight
            topMargin: root.marginTopBottom
            bottomMargin: root.marginTopBottom
        }
        spacing: Spacing.spacing8

        ContentReplace {
            id: iconReplace
            width: root.iconBox
            height: root.iconBox
            anchors.verticalCenter: parent.verticalCenter
            contentKey: root.iconSource

            Item {
                width: root.iconBox
                height: root.iconBox
                x: 0
                y: 0

                TintedIcon {
                    anchors.centerIn: parent
                    size: root.iconSize
                    source: iconReplace.displayValue
                }
            }
        }

        Column {
            spacing: Spacing.spacing4
            width: parent.width - root.iconBox - parent.spacing
            anchors.verticalCenter: parent.verticalCenter

            Item {
                width: parent.width
                height: labelText.implicitHeight

                Label {
                    id: labelText
                    text: root.label
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                ContentReplace {
                    id: valueReplace
                    // Muted <-> unmuted is the only discrete swap here.
                    // Keying on the value itself restarted the transition on every step,
                    // stuttering the readout through a scroll.
                    contentKey: root.muted ? "muted" : "value"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: valueText.implicitWidth
                    height: valueText.implicitHeight

                    Label {
                        id: valueText
                        text: valueReplace.displayValue === "muted" ? root.mutedLabel : root.valueLabel
                        color: valueReplace.displayValue === "muted" ? Colors.textColorMuted : Colors.textColor
                    }
                }
            }

            Row {
                width: parent.width
                spacing: root.barGap

                Rectangle {
                    width: Math.max(0, (parent.width - root.barGap) * root.value / 100)
                    height: root.barHeight
                    radius: height / 2
                    color: root.fillColor

                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Rectangle {
                    width: Math.max(0, (parent.width - root.barGap) * (100 - root.value) / 100)
                    height: root.barHeight
                    radius: height / 2
                    color: Colors.progressBackground

                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
