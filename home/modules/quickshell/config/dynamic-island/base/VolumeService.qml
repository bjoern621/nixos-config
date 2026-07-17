pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default sink volume/mute plus shared volume -> icon ladder.
// PwObjectTracker keeps Pipewire.defaultAudioSink alive and its audio data current.
Singleton {
    id: root

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var audioNode: Pipewire.defaultAudioSink?.audio ?? null
    // Exceeds 100 with software boost.
    readonly property int volume: Math.round((root.audioNode?.volume ?? 0) * 100)
    readonly property bool muted: root.audioNode?.muted ?? false
    readonly property url iconSource: root.iconFor(root.volume, root.muted)

    // Callers with their own volume (per-app streams) pass it in.
    // Qt.resolvedUrl anchors paths to this file,
    // so callers in any directory get an absolute url.
    function iconFor(volume, muted) {
        if (muted || volume === 0)
            return Qt.resolvedUrl("../icons/icons8-audio-muted.svg");
        if (volume <= 33)
            return Qt.resolvedUrl("../icons/icons8-low-volume.svg");
        if (volume <= 66)
            return Qt.resolvedUrl("../icons/icons8-volume.svg");
        return Qt.resolvedUrl("../icons/icons8-audio.svg");
    }
}
