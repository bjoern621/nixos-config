import Quickshell.Services.Pipewire
import QtQuick

Item {
    id: sliderMenu

    readonly property bool sliderActive: stepSlider.pressed

    implicitHeight: 40

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var audioNode: Pipewire.defaultAudioSink?.audio ?? null
    readonly property int currentVolume: Math.round((audioNode?.volume ?? 0) * 100)
    readonly property bool isMuted: audioNode?.muted ?? false
    readonly property string volumeIcon: {
        if (isMuted || currentVolume === 0) return "\uf026"
        if (currentVolume < 50) return "\uf027"
        return "\uf028"
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Colors.pillBackground
        border.width: 1
        border.color: Colors.pillBorder

        Text {
            id: volIcon
            text: sliderMenu.volumeIcon
            font.family: Typography.iconFontFamily
            font.pixelSize: Typography.fontSize14
            color: Colors.textColor
            anchors {
                left: parent.left
                leftMargin: 16
                verticalCenter: parent.verticalCenter
            }
            width: 16
            horizontalAlignment: Text.AlignHCenter
        }

        Label {
            id: pctLabel
            text: sliderMenu.currentVolume + "%"
            anchors {
                right: parent.right
                rightMargin: 16
                verticalCenter: parent.verticalCenter
            }
            width: 40
            horizontalAlignment: Text.AlignRight
        }

        StepSlider {
            id: stepSlider
            anchors {
                left: volIcon.right
                leftMargin: 10
                right: pctLabel.left
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            externalValue: sliderMenu.audioNode?.volume ?? 0
            stepSize: 0.05
            isMuted: sliderMenu.isMuted

            onMoved: (newValue) => {
                if (sliderMenu.audioNode)
                    sliderMenu.audioNode.volume = newValue
            }
        }
    }
}
