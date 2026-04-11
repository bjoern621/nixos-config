// Purpose:
// Pure Bluetooth/PipeWire data helpers for the volume output menu.
//
// Related files:
// - menus/VolumeSliderMenu.qml (UI state + rendering)
// - ../bluetooth_backend.py (imperative bluetoothctl actions)
//
// Specific concern:
// - Parse BlueZ sink names
// - Find matching Bluetooth sinks in live PipeWire nodes
// - Build output device rows (including always-visible placeholders)

function extractBluetoothMacFromNodeName(nodeName) {
    const name = (nodeName || "").toLowerCase();
    if (name.indexOf("bluez_output.") !== 0) return "";

    const parts = name.split(".");
    if (parts.length < 2) return "";

    return parts[1].replace(/_/g, ":").toUpperCase();
}

function isBluetoothSink(node) {
    return extractBluetoothMacFromNodeName(node ? node.name : "").length > 0;
}

function findSinkByBluetooth(nodes, mac, targetName) {
    if (!nodes) return null;

    const target = (targetName || "").toLowerCase();
    let fallbackSink = null;

    for (let i = 0; i < nodes.length; i++) {
        const n = nodes[i];
        if (!n || !n.isSink || n.isStream) continue;

        const sinkMac = extractBluetoothMacFromNodeName(n.name);
        if (!sinkMac) continue;

        if (sinkMac === mac) return n;

        if (target.length > 0 && !fallbackSink) {
            const description = (n.description || "").toLowerCase();
            if (description === target || description.indexOf(target) >= 0)
                fallbackSink = n;
        }
    }

    return fallbackSink;
}

function buildOutputDevices(sinks, bluetoothTargets) {
    const result = [];
    const presentTargetMacs = {};

    for (let i = 0; i < sinks.length; i++) {
        const n = sinks[i];
        const sinkMac = extractBluetoothMacFromNodeName(n.name);

        if (sinkMac.length > 0) {
            let isKnownTarget = false;
            for (let t = 0; t < bluetoothTargets.length; t++) {
                if (bluetoothTargets[t].mac === sinkMac) {
                    isKnownTarget = true;
                    break;
                }
            }

            if (isKnownTarget) {
                if (presentTargetMacs[sinkMac]) continue;
                presentTargetMacs[sinkMac] = true;
            }
        }

        result.push({
            type: "sink",
            node: n,
            name: n.description || n.name,
            isBluetooth: isBluetoothSink(n),
            mac: sinkMac,
        });
    }

    for (let j = 0; j < bluetoothTargets.length; j++) {
        const t = bluetoothTargets[j];
        if (!presentTargetMacs[t.mac]) {
            result.push({
                type: "bt-placeholder",
                node: null,
                name: t.name,
                isBluetooth: true,
                mac: t.mac,
            });
        }
    }

    return result;
}
