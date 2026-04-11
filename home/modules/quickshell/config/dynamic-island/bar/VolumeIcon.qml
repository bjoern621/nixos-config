import Quickshell.Services.Pipewire
import QtQuick
import "../"
import "../base"
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
    width: Typography.fontSize16
    height: Typography.fontSize16

    ContentReplace {
        id: volIconReplace
        contentKey: root.volumeIconSource
        anchors.fill: parent

        Item {
            id: volIcon
            anchors.centerIn: parent
            width: Typography.fontSize16
            height: Typography.fontSize16

            TintedIcon {
                anchors.centerIn: parent
                size: Typography.fontSize16
                source: volIconReplace.displayValue
            }
        }
    }
}
