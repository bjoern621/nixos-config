pragma Singleton

import Quickshell

// Hardware facts set via env by Home Manager modules a host imports.
// Unset env reads as absent.
Singleton {
    readonly property bool hasBattery: Quickshell.env("QUICKSHELL_HAS_BATTERY") === "true"
}
