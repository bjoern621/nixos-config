pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import ".."
import "../menus/BluetoothUtils.js" as BluetoothUtils

// Volume mixer behavior: node lists, output devices, master + per-app actions.
// Wraps VolumeService + Pipewire + Bluetooth. Views bind, hold no logic.
QtObject {
    id: root

    // Real output devices. Streams excluded.
    readonly property var sinkNodes: {
        const nodes = Pipewire.nodes.values;
        const result = [];
        if (!nodes)
            return result;
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n.isSink && !n.isStream)
                result.push(n);
        }
        return result;
    }

    // Per-app playback streams.
    readonly property var streamNodes: {
        const nodes = Pipewire.nodes.values;
        const result = [];
        if (!nodes)
            return result;
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n.isStream && n.audio)
                result.push(n);
        }
        return result;
    }

    // Connect + audio switch live in BluetoothConnector: machine-global state, menu per-screen.
    readonly property var outputDevices: BluetoothUtils.buildOutputDevices(root.sinkNodes, BluetoothConnector.targets)

    // Master default-sink facade.
    readonly property var audioNode: VolumeService.audioNode
    readonly property int volume: VolumeService.volume
    readonly property bool muted: VolumeService.muted
    readonly property url iconSource: VolumeService.iconSource

    readonly property int defaultSinkId: Pipewire.defaultAudioSink?.id ?? -1
    readonly property string defaultSinkDescription: Pipewire.defaultAudioSink?.description ?? "---"

    function toggleMute() {
        if (VolumeService.audioNode)
            VolumeService.audioNode.muted = !VolumeService.audioNode.muted;
    }

    function setMasterVolume(v) {
        if (VolumeService.audioNode)
            VolumeService.audioNode.volume = v;
    }

    // Preferred sink sticks. Cancel pending auto-switch first.
    function activateSink(sinkNode) {
        BluetoothConnector.cancelAutoSwitch();
        Pipewire.preferredDefaultAudioSink = sinkNode;
    }

    function activateBluetooth(deviceName, mac) {
        BluetoothConnector.connectDevice(deviceName, mac);
    }

    function toggleAppMute(streamNode) {
        const a = streamNode?.audio;
        if (a)
            a.muted = !a.muted;
    }

    // Set stream node directly for instant feedback.
    // Also drive the app's MPRIS volume so the change survives track changes.
    // Apps like Spotify re-assert internal volume onto the stream every track,
    // stream-only set is transient. Player set persists: app echoes it back onto the stream.
    // Same 0-1 scale so no compounding.
    function setAppVolume(streamNode, v) {
        const a = streamNode?.audio;
        if (a)
            a.volume = v;
        const p = root.mprisPlayerFor(streamNode);
        if (p)
            p.volume = v;
    }

    // Match stream to MPRIS player. Token match lives in VolumeService.
    function mprisPlayerFor(streamNode) {
        const players = Mpris.players?.values ?? [];
        for (let i = 0; i < players.length; i++) {
            const p = players[i];
            if (p && p.volumeSupported && VolumeService.playerMatchesStream(p, streamNode))
                return p;
        }
        return null;
    }

    // Keeps audio data current for default sink + all sinks + streams.
    property PwObjectTracker tracker: PwObjectTracker {
        objects: {
            var list = [];
            if (Pipewire.defaultAudioSink)
                list.push(Pipewire.defaultAudioSink);
            var sinks = root.sinkNodes;
            for (var i = 0; i < sinks.length; i++)
                list.push(sinks[i]);
            var streams = root.streamNodes;
            for (var j = 0; j < streams.length; j++)
                list.push(streams[j]);
            return list;
        }
    }
}
