import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Effects
import "../"
import "../animations"

Item {
    id: root
    readonly property int volume: Math.round((Pipewire.defaultAudioSink?.audio.volume ?? 0) * 100)
    readonly property bool isMuted: Pipewire.defaultAudioSink?.audio.muted ?? false

    readonly property string volumeIconSource: {
        if (isMuted || volume === 0)
            return "../icons/icons8-sound-speaker.svg";
        if (volume <= 33)
            return "../icons/icons8-low-volume.svg";
        if (volume <= 66)
            return "../icons/icons8-volume.svg";
        return "../icons/icons8-audio.svg";
    }

    anchors.verticalCenter: parent.verticalCenter
    width: 20
    height: 20

    ContentReplace {
        id: volIconReplace
        contentKey: root.volumeIconSource
        anchors.fill: parent

        Item {
            id: volIcon
            anchors.centerIn: parent
            width: 18
            height: 18

            Image {
                id: volIconImage
                anchors.fill: parent
                source: volIconReplace.displayValue
                sourceSize: Qt.size(36, 36)
                fillMode: Image.PreserveAspectFit
                smooth: true
                antialiasing: true
                visible: false
            }

            MultiEffect {
                anchors.fill: volIconImage
                source: volIconImage
                colorization: 1.0
                colorizationColor: Colors.textColor
            }
        }
    }
}
