import QtQuick
import ".."

// Proportional wheel scroll, ~rowsPerNotch rows per mouse notch (120 = one notch).
// Each notch glides to its target over `duration` ms.
// Place as a child of the Flickable/ListView it drives. Mouse + touchpad.
WheelHandler {
    id: root

    property Flickable target: parent
    property real rowStride: 42        // rowHeight + spacing
    property real rowsPerNotch: 1.5
    property int duration: 120

    // Emitted on every notch. Consumers drop keyboard-nav mode on it.
    signal scrolled

    // Glide writes contentY via this.
    // Other writers leave contentY off it.
    property real _glideY: 0
    on_GlideYChanged: if (glide.running && target)
        target.contentY = _glideY

    // Held in properties: pointer handler has no default property for children.
    readonly property NumberAnimation _glide: NumberAnimation {
        id: glide
        target: root
        property: "_glideY"
        easing.type: Easing.OutCubic
        duration: root.duration
    }

    // Handle drag, keyboard nav, model reset write contentY too.
    // Their write cancels in-flight glide.
    readonly property Connections _externalWrite: Connections {
        target: root.target
        function onContentYChanged() {
            if (glide.running && Math.abs(root.target.contentY - root._glideY) > 0.5)
                glide.stop();
        }
    }

    // Step during glide stacks onto its target.
    // Fast spins keep every step.
    function glideBy(deltaY) {
        const maxY = Math.max(0, target.contentHeight - target.height);
        const fromY = glide.running ? glide.to : target.contentY;
        glide.stop();
        _glideY = target.contentY;
        glide.from = target.contentY;
        glide.to = Math.max(0, Math.min(fromY + deltaY, maxY));
        glide.start();
    }

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
        if (!target)
            return;
        glideBy(-(event.angleDelta.y / 120) * rowStride * rowsPerNotch);
        scrolled();
    }
}
