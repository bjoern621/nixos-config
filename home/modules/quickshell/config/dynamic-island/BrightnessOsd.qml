import QtQuick

// Brightness OSD: shows when /tmp/qs-brightness is written by the brightness keybinds.
OsdWindow {
    watchPath: "/tmp/qs-brightness"
    osdTitle: "Helligkeit"
    osdIcon: "\uf185"
}
