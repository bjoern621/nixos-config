pragma Singleton

import QtQuick
import Quickshell

// Startup settle guard.
// Pipewire and UPower publish first values after shell start, as ordinary property changes.
// Change reactions must ignore them until settled.
// Else shell pops a volume OSD or battery warning for state it only just read.
Singleton {
    id: root

    readonly property int settleMs: 2000
    property bool settled: false

    Timer {
        interval: root.settleMs
        running: true
        onTriggered: root.settled = true
    }
}
