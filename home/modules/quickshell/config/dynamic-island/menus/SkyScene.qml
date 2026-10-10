import QtQuick
import QtQuick.Shapes
import "SkyScene.js" as Sky

// Stylized weather sky. Self-contained: no theme tokens, since the sky
// looks the same in every shell theme. Hour drives the sun/moon arc and gradient;
// condition + temp come from the forecast. Animation runs only while `animating`.
//
// Qt 6 rasterizes a Canvas in software and re-uploads it per repaint, so a scene-sized
// Canvas repainted per frame would hold a core and stall the scene graph thread
// of every shell window. The still parts (sky gradient, sun or moon, hills, vignette)
// hold their own Canvas and repaint on an input change. Every moving part sits in
// scene graph items: clouds and fog bands paint once into small textures and move
// by position, stars, rain and snow draw as plain rectangles, the bolt as a Shape.
Item {
    id: root

    property real hour: 13          // 0..24, drives sky + sun/moon position
    property string condition: "clear"   // clear|partly|cloudy|fog|rain|snow|thunder
    property real temp: 18
    property real sunrise: 6        // local sunrise/sunset hours; warp the arc onto them
    property real sunset: 20
    property real latitude: 0       // place + date -> seasonal noon sun height and hue
    property int dayOfYear: 81      // 1..365; 81 (equinox) leaves the season neutral
    property real cloud: 0          // 0..1 cloud cover; drives puff count + opacity
    property real wind: 0           // km/h; cloud drift speed + rain/snow slant
    property real windDir: 0        // meteorological degrees the wind comes from
    property real precip: 0         // mm; rain/drizzle particle density
    property real snow: 0           // cm; snow particle density
    property real moonPhase: 0      // 0..1; 0/1 new moon, 0.5 full
    property bool animating: false  // gate: true only while the calendar menu is open

    // Hill shapes and lightning state, owned here, mutated by Sky. Not a binding source.
    property var _p: ({})

    // Derived scene values shared by every layer. A fresh object per input change,
    // so one change signal covers all inputs.
    readonly property var _scene: Sky.scene(height, { hour: root.hour, base: root.condition, sr: root.sunrise, ss: root.sunset, lat: root.latitude, doy: root.dayOfYear, cloud: root.cloud, wind: root.wind, windDir: root.windDir, precip: root.precip, snow: root.snow, moon: root.moonPhase })

    // Frame counter the twinkle, sway and flap phases read; one step per tick.
    property int _frame: 0
    property real _flash: 0
    property var _boltPts: []

    // One step of every particle. Delegates advance themselves on it.
    signal tick

    // Scrubbing repaints even when the animation timer is idle.
    on_SceneChanged: { back.requestPaint(); hills.requestPaint(); }
    onWidthChanged: vignette.requestPaint()
    onHeightChanged: vignette.requestPaint()

    component Layer: Canvas {
        anchors.fill: parent
        renderStrategy: Canvas.Threaded
    }

    // One pass of the bolt glow; pass = [width, rgb, alpha] from Sky.BOLT_PASS.
    component BoltPass: ShapePath {
        required property var pass

        strokeWidth: pass[0]
        strokeColor: Qt.rgba(pass[1][0] / 255, pass[1][1] / 255, pass[1][2] / 255, Math.max(0, root._flash) * pass[2])
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        PathPolyline {
            path: root._boltPts
        }
    }

    Layer {
        id: back
        onPaint: Sky.paintBack(getContext("2d"), width, height, root._scene)
    }

    Item {
        anchors.fill: parent
        visible: root._scene.starAlpha > 0.03

        Repeater {
            model: 95

            Rectangle {
                readonly property real fx: Math.random()
                readonly property real fy: Math.random()
                readonly property real r: Math.random() * 1.1 + 0.35
                readonly property real tw: Math.random() * 6.28

                x: fx * root.width - r
                y: fy * root.height * 0.66 - r
                width: 2 * r
                height: 2 * r
                radius: r
                antialiasing: true
                color: "white"
                opacity: root._scene.starAlpha * (0.5 + 0.5 * Math.sin(root._frame * 0.05 + tw)) * 0.85
            }
        }

        Repeater {
            model: 6

            Item {
                readonly property real fx: Math.random()
                readonly property real fy: Math.random()
                readonly property real size: Math.random() * 2 + 2.5
                readonly property real tw: Math.random() * 6.28
                readonly property real t2: 0.4 + 0.6 * Math.sin(root._frame * 0.06 + tw)
                readonly property real len: size * (0.7 + t2 * 0.5)

                x: fx * root.width
                y: fy * root.height * 0.5
                opacity: root._scene.starAlpha * t2

                Rectangle { x: -parent.len; y: -0.65; width: 2 * parent.len; height: 1.3; radius: 0.65; antialiasing: true; color: "white" }
                Rectangle { x: -0.65; y: -parent.len; width: 1.3; height: 2 * parent.len; radius: 0.65; antialiasing: true; color: "white" }
                Rectangle { x: -1.1; y: -1.1; width: 2.2; height: 2.2; radius: 1.1; antialiasing: true; color: "white"; opacity: 0.6 }
            }
        }
    }

    // Each cloud holds its puff as a texture and drifts by position.
    Repeater {
        model: 9

        Canvas {
            id: cloudItem

            required property int index
            readonly property real sizeF: 0.5 + Math.random() * 0.9
            readonly property real lane: 0.1 + Math.random() * 0.32
            readonly property real speed: (0.08 + Math.random() * 0.22) * sizeF
            readonly property real fx: Math.random()
            // Puff scale and wrap margin, as Sky.puff reads them.
            readonly property real s: sizeF * root.height / 200
            readonly property real margin: 90 * sizeF
            readonly property var colors: Sky.cloudColors(root._scene)
            // Centre x. The binding holds until the first tick replaces it.
            property real cx: fx * root.width

            visible: index < root._scene.cloudCount
            x: cx - 50 * s
            y: root.height * lane - 19 * s
            width: 100 * s
            height: 43 * s
            renderStrategy: Canvas.Threaded
            onColorsChanged: requestPaint()
            onPaint: Sky.paintPuff(getContext("2d"), width, height, s, colors)

            Connections {
                target: root
                function onTick() {
                    cloudItem.cx += cloudItem.speed * root._scene.driftMag * root._scene.driftDir;
                    if (cloudItem.cx > root.width + cloudItem.margin)
                        cloudItem.cx = -cloudItem.margin;
                    if (cloudItem.cx < -cloudItem.margin)
                        cloudItem.cx = root.width + cloudItem.margin;
                }
            }
        }
    }

    Repeater {
        model: 3

        Canvas {
            id: bird

            readonly property real fx: Math.random()
            readonly property real lane: 0.18 + Math.random() * 0.2
            readonly property real speed: 0.25 + Math.random() * 0.2
            readonly property real ph: Math.random() * 6.28
            property real bx: fx * root.width

            visible: root._scene.birds
            x: bx - 5
            y: root.height * lane - 5
            width: 10
            height: 10
            renderStrategy: Canvas.Threaded
            onPaint: Sky.paintBird(getContext("2d"), Math.sin(root._frame * 0.12 + ph) * 3)

            Connections {
                target: root
                enabled: bird.visible
                function onTick() {
                    bird.bx += bird.speed;
                    if (bird.bx > root.width + 20)
                        bird.bx = -20;
                    bird.requestPaint();
                }
            }
        }
    }

    Layer {
        id: hills
        onPaint: Sky.paintHills(getContext("2d"), width, height, root._scene, root._p)
    }

    Item {
        anchors.fill: parent
        visible: root._scene.raining

        Repeater {
            model: 170

            Rectangle {
                id: drop

                required property int index
                readonly property real fx: Math.random()
                readonly property real fy: Math.random()
                readonly property real len: 9 + Math.random() * 11
                readonly property real speed: 6 + Math.random() * 3.5
                property real dx: fx * root.width
                property real dy: fy * root.height

                visible: index < root._scene.rainCount
                x: dx
                y: dy
                width: 1.5
                height: len
                radius: 0.75
                antialiasing: true
                rotation: Math.atan2(root._scene.slant * 1.7, len) * 180 / Math.PI
                color: Qt.rgba(200 / 255, 222 / 255, 246 / 255, 0.35 + (len - 9) / 11 * 0.4)

                Connections {
                    target: root
                    enabled: drop.visible
                    function onTick() {
                        drop.dy += drop.speed;
                        drop.dx += root._scene.slant;
                        if (drop.dy > root.height * 0.96) {
                            drop.dy = -10;
                            drop.dx = Math.random() * root.width;
                        }
                        if (drop.dx > root.width)
                            drop.dx -= root.width;
                        if (drop.dx < 0)
                            drop.dx += root.width;
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root._scene.snowing

        Repeater {
            model: 95

            Rectangle {
                id: flake

                required property int index
                readonly property real ss: Math.random()
                readonly property real fx: Math.random()
                readonly property real fy: Math.random()
                readonly property real r: 1.2 + ss * 2.6
                readonly property real speed: 0.5 + ss * 1.1
                readonly property real d: Math.random() * 6.28
                property real dx: fx * root.width
                property real dy: fy * root.height

                visible: index < root._scene.snowCount
                x: dx - r
                y: dy - r
                width: 2 * r
                height: 2 * r
                radius: r
                antialiasing: true
                color: "white"
                opacity: 0.5 + Math.random() * 0.5

                Connections {
                    target: root
                    enabled: flake.visible
                    function onTick() {
                        flake.dy += flake.speed;
                        flake.dx += Math.sin(root._frame * 0.02 + flake.d) * 0.7 + root._scene.gust;
                        if (flake.dy > root.height * 0.97) {
                            flake.dy = -6;
                            flake.dx = Math.random() * root.width;
                        }
                        if (flake.dx > root.width)
                            flake.dx -= root.width;
                        if (flake.dx < 0)
                            flake.dx += root.width;
                    }
                }
            }
        }
    }

    // Fog bands: each a gradient ellipse painted once, swaying by position.
    Repeater {
        model: 4

        Canvas {
            required property int index

            visible: root._scene.fogging
            x: -18 + Math.sin(root._frame * 0.012 + index * 1.5) * 18
            y: root._scene.horizonPix - 40 + index * 20 - 15
            width: root.width + 36
            height: 30
            renderStrategy: Canvas.Threaded
            onPaint: Sky.paintFog(getContext("2d"), width, height, index)
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root._scene.storming
        color: "#fffceb"
        opacity: root._flash * 0.42
    }

    Shape {
        anchors.fill: parent
        visible: root._scene.storming && root._flash > 0
        preferredRendererType: Shape.CurveRenderer

        BoltPass { pass: Sky.BOLT_PASS[0] }
        BoltPass { pass: Sky.BOLT_PASS[1] }
        BoltPass { pass: Sky.BOLT_PASS[2] }
        BoltPass { pass: Sky.BOLT_PASS[3] }
    }

    Layer {
        id: vignette
        onPaint: Sky.paintVignette(getContext("2d"), width, height)
    }

    // ~30fps while open. Idle (menu closed) -> stopped, nothing drawn on battery.
    Timer {
        interval: 33
        repeat: true
        running: root.animating
        onTriggered: {
            root._frame++;
            root.tick();
            if (root._scene.storming) {
                if (Sky.stepStorm(root._p, root.width, root.height))
                    root._boltPts = root._p.boltPts;
                root._flash = root._p.flash;
            }
        }
    }
}
