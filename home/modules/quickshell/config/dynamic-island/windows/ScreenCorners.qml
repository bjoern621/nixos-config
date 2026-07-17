import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._WlrLayerShell
import QtQuick

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: root
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "quickshell-noblur"
            WlrLayershell.layer: WlrLayer.Overlay

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            exclusiveZone: 0
            color: "transparent"
            mask: Region {}

            property int cornerRadius: 20

            CornerMask {
                radius: root.cornerRadius
                corner: 0
                x: 0
                y: 0
            }

            CornerMask {
                radius: root.cornerRadius
                corner: 1
                x: root.width - width
                y: 0
            }

            CornerMask {
                radius: root.cornerRadius
                corner: 2
                x: 0
                y: root.height - height
            }

            CornerMask {
                radius: root.cornerRadius
                corner: 3
                x: root.width - width
                y: root.height - height
            }
        }
    }

    component CornerMask: Item {
        id: mask

        property int radius: 20 // 12px inner radius with 8px offset keeps inner and outer arcs concentric, so outer radius is 20px
        // 0 = top-left, 1 = top-right, 2 = bottom-left, 3 = bottom-right
        property int corner: 0

        width: radius
        height: radius

        Canvas {
            id: maskCanvas
            anchors.fill: parent
            antialiasing: true

            // Fakes the rounded bezel of a physical display, so black is the
            // absence of screen rather than a themed surface. Not a Colors token.
            onPaint: {
                var context = getContext("2d");
                context.reset();

                context.fillStyle = "#000000";
                context.fillRect(0, 0, width, height);

                context.globalCompositeOperation = "destination-out";
                context.beginPath();

                if (mask.corner === 0) {
                    context.moveTo(width, height);
                    context.arc(width, height, width, Math.PI, 1.5 * Math.PI, false);
                } else if (mask.corner === 1) {
                    context.moveTo(0, height);
                    context.arc(0, height, width, 1.5 * Math.PI, 2 * Math.PI, false);
                } else if (mask.corner === 2) {
                    context.moveTo(width, 0);
                    context.arc(width, 0, width, 0.5 * Math.PI, Math.PI, false);
                } else {
                    context.moveTo(0, 0);
                    context.arc(0, 0, width, 0, 0.5 * Math.PI, false);
                }

                context.closePath();
                context.fill();
            }
        }

        // Canvas repaints itself on resize, which covers radius. corner has no
        // geometry to change, so it needs this.
        onCornerChanged: maskCanvas.requestPaint()
    }
}
