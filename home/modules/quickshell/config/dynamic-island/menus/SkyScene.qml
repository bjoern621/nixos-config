import QtQuick
import "SkyScene.js" as Sky

// Stylized weather sky on a Canvas. Self-contained: no theme tokens, since the sky
// looks the same in every shell theme. Hour drives the sun/moon arc and gradient;
// condition + temp come from the forecast. Animation runs only while `animating`.
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

    // GPU FBO for the live loop; overridable to Canvas.Image for a software render.
    property alias renderTarget: canvas.renderTarget

    // Particle + frame state, owned here, mutated by Sky.paint. Not a binding source.
    property var _p: ({})
    property bool _seeded: false

    function _seed() {
        if (width > 0 && height > 0) {
            Sky.seed(root._p, width, height);
            root._seeded = true;
        }
    }

    onWidthChanged: { _seed(); canvas.requestPaint(); }
    onHeightChanged: { _seed(); canvas.requestPaint(); }
    Component.onCompleted: { _seed(); canvas.requestPaint(); }

    // Scrubbing repaints even when the animation timer is idle.
    onHourChanged: canvas.requestPaint()
    onConditionChanged: canvas.requestPaint()
    onTempChanged: canvas.requestPaint()
    onSunriseChanged: canvas.requestPaint()
    onSunsetChanged: canvas.requestPaint()
    onLatitudeChanged: canvas.requestPaint()
    onDayOfYearChanged: canvas.requestPaint()
    onCloudChanged: canvas.requestPaint()
    onWindChanged: canvas.requestPaint()
    onWindDirChanged: canvas.requestPaint()
    onPrecipChanged: canvas.requestPaint()
    onSnowChanged: canvas.requestPaint()
    onMoonPhaseChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        // FBO renders on the GPU for the animated loop. Overridable so an offscreen
        // software render (verification) can use Canvas.Image.
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        onPaint: {
            if (!root._seeded)
                root._seed();
            var ctx = getContext("2d");
            Sky.paint(ctx, width, height, { hour: root.hour, base: root.condition, temp: root.temp, sr: root.sunrise, ss: root.sunset, lat: root.latitude, doy: root.dayOfYear, cloud: root.cloud, wind: root.wind, windDir: root.windDir, precip: root.precip, snow: root.snow, moon: root.moonPhase }, root._p);
        }
    }

    // ~30fps while open. Idle (menu closed) -> stopped, nothing drawn on battery.
    Timer {
        interval: 33
        repeat: true
        running: root.animating
        onTriggered: canvas.requestPaint()
    }
}
