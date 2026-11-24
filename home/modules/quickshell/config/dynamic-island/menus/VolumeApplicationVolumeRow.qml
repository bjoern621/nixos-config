pragma ComponentBehavior: Bound

import QtQuick
import "../"

VolumeLevelRow {
    id: root

    required property var streamNode
    property var controller

    readonly property var appAudio: streamNode.audio

    title: root.streamNode.description || root.streamNode.name
    level: root.appAudio?.volume ?? 0
    muted: root.appAudio?.muted ?? false

    onMoved: newLevel => root.controller.setAppVolume(root.streamNode, newLevel)
    onMuteTapped: root.controller.toggleAppMute(root.streamNode)
}
