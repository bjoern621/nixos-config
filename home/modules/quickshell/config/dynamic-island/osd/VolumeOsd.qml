import Quickshell
import QtQuick
import "../"

// Volume OSD.
// VolumeService owns the sink state and the icon ladder.
Scope {
    id: volumeScope

    // The slider menu already shows the value.
    // ShellStartup covers Pipewire publishing its first volume after the shell is up.
    readonly property bool suppressOsd: Globals.volumeSliderOpen || !ShellStartup.settled

    // Capped for the progress bar.
    // The readout keeps the boosted value.
    readonly property int osdValue: Math.min(100, VolumeService.volume)

    Connections {
        target: VolumeService

        function onVolumeChanged() {
            volumeScope.triggerShow();
        }
        function onMutedChanged() {
            volumeScope.triggerShow();
        }
    }

    function triggerShow() {
        if (volumeScope.suppressOsd)
            return;
        osd.showOsd();
    }

    OsdWindow {
        id: osd
        iconSource: VolumeService.iconSource
        label: "Lautstärke"
        value: volumeScope.osdValue
        valueLabel: VolumeService.volume + " %"
        mutedLabel: "stumm"
        muted: VolumeService.muted
        fillColor: VolumeService.muted ? Colors.progressMuted : Colors.accentColor
    }
}
