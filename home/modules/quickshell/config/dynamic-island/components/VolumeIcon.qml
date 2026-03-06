import Quickshell.Services.Pipewire
import QtQuick

Text {
    // readonly property int volume: Math.round((Pipewire.defaultAudioSink?.audio.volume ?? 0) * 100)
    // readonly property bool isMuted: Pipewire.defaultAudioSink?.audio.muted ?? false

    // property string volumeIcon: {
    //     if (isMuted || volume === 0) return "\uf026"
    //     if (volume < 50) return "\uf027"
    //     return "\uf028"
    // }

    text: "volumeIcon"
    font.family: Typography.iconFontFamily
    font.pixelSize: Typography.fontSize14
    color: Colors.textColor
    anchors.verticalCenter: parent.verticalCenter
}
