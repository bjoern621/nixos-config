.pragma library

// Pure presentation helpers for BluetoothMenu / BluetoothDeviceRow.
// Stateless, so one engine copy serves every importer (per-screen menus).
//
// Related files:
// - base/BluetoothService.qml (state + actions over Quickshell.Bluetooth)
// - menus/BluetoothMenu.qml (view)
// - menus/BluetoothDeviceRow.qml (row rendering)
//
// Concern:
// - Map a BlueZ device (freedesktop icon name + device name) to a local asset.
// - German type label for the detail panel.
// - Battery reading normalized to whole percent, or -1 when unreported.

// Returns a basename in icons/. Row prepends "../icons/" so the URL resolves
// against the row file, not this library (which has no base URL).
function iconAsset(icon, name) {
    const i = (icon || "").toLowerCase();
    const n = (name || "").toLowerCase();

    // freedesktop Device1.Icon wins when BlueZ provides it.
    if (i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0)
        return "bt-headset.svg";
    if (i.indexOf("speaker") >= 0)
        return "bt-speaker.svg";
    if (i.indexOf("mouse") >= 0)
        return "bt-mouse.svg";
    if (i.indexOf("keyboard") >= 0)
        return "bt-keyboard.svg";
    if (i.indexOf("phone") >= 0)
        return "bt-phone.svg";
    if (i.indexOf("watch") >= 0)
        return "bt-watch.svg";
    if (i.indexOf("gaming") >= 0 || i.indexOf("joystick") >= 0 || i.indexOf("gamepad") >= 0)
        return "bt-gamepad.svg";

    // Name heuristics catch earbuds and devices that leave Icon empty.
    if (n.indexOf("buds") >= 0 || n.indexOf("airpod") >= 0 || n.indexOf("earbud") >= 0)
        return "bt-earbuds.svg";
    if (n.indexOf("headphone") >= 0 || n.indexOf("headset") >= 0 || n.indexOf("wh-") >= 0)
        return "bt-headset.svg";
    if (n.indexOf("speaker") >= 0 || n.indexOf("soundcore") >= 0 || n.indexOf("boom") >= 0 || n.indexOf("flip") >= 0)
        return "bt-speaker.svg";
    if (n.indexOf("mouse") >= 0 || n.indexOf("mx ") >= 0)
        return "bt-mouse.svg";
    if (n.indexOf("keyboard") >= 0 || n.indexOf("keychron") >= 0)
        return "bt-keyboard.svg";
    if (n.indexOf("watch") >= 0)
        return "bt-watch.svg";
    if (i.indexOf("audio") >= 0)
        return "bt-speaker.svg";
    if (n.indexOf("phone") >= 0 || n.indexOf("iphone") >= 0 || n.indexOf("pixel") >= 0 || n.indexOf("galaxy") >= 0)
        return "bt-phone.svg";

    return "icons8-bluetooth.svg";
}

function typeLabel(icon, name) {
    const asset = iconAsset(icon, name);
    switch (asset) {
    case "bt-headset.svg":
        return "Kopfhörer";
    case "bt-earbuds.svg":
        return "Ohrhörer";
    case "bt-speaker.svg":
        return "Lautsprecher";
    case "bt-mouse.svg":
        return "Maus";
    case "bt-keyboard.svg":
        return "Tastatur";
    case "bt-phone.svg":
        return "Telefon";
    case "bt-watch.svg":
        return "Uhr";
    case "bt-gamepad.svg":
        return "Controller";
    default:
        return "Gerät";
    }
}

// Whole percent, or -1 when the device reports no battery.
// Quickshell publishes battery as 0.0..1.0; a value above 1 is treated as
// already-percent so a future scale change cannot render 7200 %.
function batteryPercent(device) {
    if (!device || !device.batteryAvailable)
        return -1;
    let b = device.battery;
    if (b === undefined || b === null || isNaN(b))
        return -1;
    if (b <= 1)
        b *= 100;
    return Math.max(0, Math.min(100, Math.round(b)));
}
