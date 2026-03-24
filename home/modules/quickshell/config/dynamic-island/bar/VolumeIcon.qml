import Quickshell.Services.Pipewire
import QtQuick
import "../"
import "../animations"

Item {
    id: root
    readonly property int volume: Math.round((Pipewire.defaultAudioSink?.audio.volume ?? 0) * 100)
    readonly property bool isMuted: Pipewire.defaultAudioSink?.audio.muted ?? false

    property string volumeIcon: {
        if (isMuted || volume === 0) return "\uf026"
        if (volume < 50) return "\uf027"
        return "\uf028"
    }

    anchors.verticalCenter: parent.verticalCenter
    width: 20
    height: volIcon.implicitHeight

    ContentReplace {
        id: volIconReplace
        contentKey: root.volumeIcon
        anchors.fill: parent

        Text {
            id: volIcon
            text: volIconReplace.displayValue
            font.family: Typography.iconFontFamily
            font.pixelSize: Typography.fontSize14
            color: Colors.textColor
            width: parent.width
            height: parent.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
