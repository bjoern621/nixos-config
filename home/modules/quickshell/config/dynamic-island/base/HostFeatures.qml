pragma Singleton

import Quickshell

// Hardware switches from host flake, set via env by quickshell.nix.
// Unset env reads as laptop.
Singleton {
    readonly property bool hasBattery: Quickshell.env("QUICKSHELL_HAS_BATTERY") !== "false"
}
