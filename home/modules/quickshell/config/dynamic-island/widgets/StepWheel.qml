import QtQuick
import ".."

// Proportional wheel scroll, ~rowsPerNotch rows per mouse notch (120 = one notch).
// Place as a child of the Flickable/ListView it drives. Mouse + touchpad.
WheelHandler {
    property Flickable target: parent
    property real rowStride: 42        // rowHeight + spacing
    property real rowsPerNotch: 1.5

    // Emitted on every notch. Consumers drop keyboard-nav mode on it.
    signal scrolled

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
        if (!target)
            return;
        const step = rowStride * rowsPerNotch;
        const maxY = Math.max(0, target.contentHeight - target.height);
        const delta = -(event.angleDelta.y / 120) * step;
        target.contentY = Math.max(0, Math.min(target.contentY + delta, maxY));
        scrolled();
    }
}
