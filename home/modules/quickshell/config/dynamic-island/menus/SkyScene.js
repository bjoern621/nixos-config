.pragma library

// Stylized weather sky behind SkyScene.qml.
// Layered flat-landscape: 3-stop time-of-day sky, sun/moon behind parallax hills,
// two-tone clouds, stylized rain/snow/fog/lightning. Hour-driven; condition
// comes from the forecast. scene(h,inp) derives the per-frame values every layer
// reads. The still layers paint on a Canvas: paintBack, paintHills, paintVignette.
// Clouds, fog bands and birds paint their own small textures (paintPuff, paintFog,
// paintBird); the QML moves them. Hill shapes and lightning state live in a plain
// object P owned by SkyScene.qml; seed(P,w,h) fills it, stepStorm advances the flash.
//
// Qt Context2D note: ellipse(x,y,w,h) takes a bounding box, not HTML5's
// (cx,cy,rx,ry,rot,a,b). fillEllipse wraps that. arc() matches HTML5.

// Reference sun times the sky palette + arc geometry are tuned around. The real
// sunrise/sunset come from the forecast; warp() maps clock hour into this frame
// so the whole scene tracks them without retuning every keyframe.
var SUNR = 6, SUNS = 20;
// Lightning timing in ms, not frames: a dropped frame must not stretch the flash.
var FLASH_MS = 600, BOLT_GAP_MS = 2600, BOLT_JITTER_MS = 3400;

function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }

// Clock hour -> reference-frame hour, so real sunrise sr lands on SUNR and real
// sunset ss on SUNS. Piecewise-linear across night/day/night; midnight stays
// fixed. Bad or default (sr=SUNR, ss=SUNS) data collapses to the identity map.
function warp(h, sr, ss) {
    if (!(sr > 0) || !(ss > sr) || !(ss < 24)) return h;
    if (h < sr) return h / sr * SUNR;
    if (h < ss) return SUNR + (h - sr) / (ss - sr) * (SUNS - SUNR);
    return SUNS + (h - ss) / (24 - ss) * (24 - SUNS);
}

// Day-of-year (1..365) + latitude (deg) -> seasonal solar geometry.
// decl: declination sinusoid, 0 near the March equinox (day ~81).
// altScale: fraction of the zenith the noon sun reaches, so the arc rides low in
// winter, high in summer. season: -1 deep winter .. +1 midsummer, hemisphere-aware.
function solar(doy, lat) {
    var s = Math.sin(2 * Math.PI / 365 * (doy - 81));
    var noonElev = 90 - Math.abs(lat - 23.44 * s);
    return { altScale: clamp(noonElev / 90, 0.08, 1), season: clamp(s * (lat < 0 ? -1 : 1), -1, 1) };
}
function lerp(a, b, f) { return a + (b - a) * f; }

// OKLab perceptual color space (Björn Ottosson). Every color blend runs through it
// so gradients and mixes move on a natural hue/lightness path, not the greyed
// midpoint sRGB interpolation gives between saturated colors.
function _srgbLin(c) { c /= 255; return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
function _linSrgb(c) { c = c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055; return c < 0 ? 0 : (c > 1 ? 255 : c * 255); }
function _toLab(c) {
    var r = _srgbLin(c[0]), g = _srgbLin(c[1]), b = _srgbLin(c[2]);
    var l = Math.cbrt(0.4122214708*r + 0.5363325363*g + 0.0514459929*b);
    var m = Math.cbrt(0.2119034982*r + 0.6806995451*g + 0.1073969566*b);
    var s = Math.cbrt(0.0883024619*r + 0.2817188376*g + 0.6299787005*b);
    return [0.2104542553*l + 0.7936177850*m - 0.0040720468*s,
            1.9779984951*l - 2.4285922050*m + 0.4505937099*s,
            0.0259040371*l + 0.7827717662*m - 0.8086757660*s];
}
function _fromLab(L) {
    var l = L[0] + 0.3963377774*L[1] + 0.2158037573*L[2];
    var m = L[0] - 0.1055613458*L[1] - 0.0638541728*L[2];
    var s = L[0] - 0.0894841775*L[1] - 1.2914855480*L[2];
    l = l*l*l; m = m*m*m; s = s*s*s;
    return [_linSrgb( 4.0767416621*l - 3.3077115913*m + 0.2309699292*s),
            _linSrgb(-1.2684380046*l + 2.6097574011*m - 0.3413193965*s),
            _linSrgb(-0.0041960863*l - 0.7034186147*m + 1.7076147010*s)];
}
// Perceptual color lerp, same signature as the old sRGB version. Every caller and
// gradient stop interpolates in OKLab through this one function.
function lc(a, b, f) {
    var la = _toLab(a), lb = _toLab(b);
    var o = _fromLab([la[0]+(lb[0]-la[0])*f, la[1]+(lb[1]-la[1])*f, la[2]+(lb[2]-la[2])*f]);
    return [Math.round(o[0]), Math.round(o[1]), Math.round(o[2])];
}
// Densify a linear-gradient segment p0..p1 with OKLab-interpolated stops, so Qt's
// per-stop sRGB fill tracks the perceptual path between the two colors.
function skyStops(g, c0, c1, p0, p1) {
    for (var i = 0; i <= 6; i++) { var f = i / 6; g.addColorStop(p0 + (p1 - p0) * f, rgba(lc(c0, c1, f))); }
}
function rgba(c, a) { return "rgba(" + (c[0]|0) + "," + (c[1]|0) + "," + (c[2]|0) + "," + (a == null ? 1 : a) + ")"; }
function shade(c, f) { return [c[0]*f, c[1]*f, c[2]*f]; }

function isDay(h) { return h >= SUNR && h < SUNS; }

// 3-stop sky keyframes [hour, top, mid, horizon], from sunrise/sunset palettes.
var SKY = [
    [0,   [11,18,51],  [18,28,74],  [37,52,92]],
    [4.5, [23,32,71],  [55,52,104], [120,86,120]],
    [6,   [31,58,134], [91,111,176],[240,164,99]],
    [7.5, [39,111,198],[107,160,221],[255,212,136]],
    [10,  [30,103,200],[92,155,230],[191,226,244]],
    [13,  [24,95,207], [79,151,232],[201,230,247]],
    [16,  [30,99,192], [91,147,218],[207,224,238]],
    [18,  [43,63,134], [214,118,90],[255,206,127]],
    [19.5,[33,26,84],  [176,71,95], [255,157,77]],
    [21,  [19,26,64],  [54,47,99],  [109,74,110]],
    [24,  [11,18,51],  [18,28,74],  [37,52,92]]
];
function skyAt(h) {
    var a, b, f;
    for (var i = 1; i < SKY.length; i++) {
        if (h <= SKY[i][0]) { a = SKY[i-1]; b = SKY[i]; f = (h - a[0]) / (b[0] - a[0]); break; }
    }
    if (!a) { a = SKY[SKY.length-1]; b = a; f = 0; }
    return { top: lc(a[1],b[1],f), mid: lc(a[2],b[2],f), hor: lc(a[3],b[3],f) };
}

// Mild seasonal cast on the sky palette. season: -1 winter .. +1 summer. Summer
// warms; winter cools, desaturates and dims. Subtle by design so the time-of-day
// palette still leads and only the character shifts across the year.
function tintSeason(sky, season) {
    if (!season) return sky;
    var target = season > 0 ? [255,236,200] : [206,220,246], wf = 0.09 * Math.abs(season);
    function ap(c) {
        var o = lc(c, target, wf);
        if (season < 0) {
            var g = (o[0] + o[1] + o[2]) / 3;
            o = shade(lc(o, [g,g,g], 0.14 * -season), 1 - 0.06 * -season);
        }
        return o;
    }
    return { top: ap(sky.top), mid: ap(sky.mid), hor: ap(sky.hor) };
}

var SEV = { clear:0, partly:0.12, cloudy:0.46, fog:0.5, rain:0.66, snow:0.44, thunder:0.82 };
function grade(sky, sev, base) {
    if (sev <= 0) return sky;
    var slate = (base === "rain" || base === "thunder") ? [58,74,104] : [92,100,116];
    var m = sev * 0.55, d = 1 - sev * 0.24;
    return { top: shade(lc(sky.top,slate,m*0.7),d), mid: shade(lc(sky.mid,slate,m),d), hor: shade(lc(sky.hor,slate,m*0.85),d) };
}
function daylight(h) {
    if (h <= SUNR - 1.2 || h >= SUNS + 1.2) return 0;
    var p = (h - SUNR) / (SUNS - SUNR), alt = Math.sin(clamp(p,0,1) * Math.PI);
    if (h < SUNR) alt = Math.max(0, 1 - (SUNR - h) / 1.2);
    if (h > SUNS) alt = Math.max(0, 1 - (h - SUNS) / 1.2);
    return clamp(alt, 0, 1);
}

function seed(P, w, h) {
    var rnd = Math.random;
    P.flash = 0; P.boltPts = null; P.nextBolt = BOLT_GAP_MS + rnd()*BOLT_JITTER_MS; P.w = w; P.h = h;
    P.hills = [
        { by:0.70, amp:0.045, f1:0.010, p1:rnd()*6.28, f2:0.021, p2:rnd()*6.28, sh:0.74 },
        { by:0.80, amp:0.060, f1:0.008, p1:rnd()*6.28, f2:0.019, p2:rnd()*6.28, sh:0.52 },
        { by:0.90, amp:0.075, f1:0.006, p1:rnd()*6.28, f2:0.015, p2:rnd()*6.28, sh:0.32 }
    ];
}
function ensure(P, w, h) { if (!P.hills || P.w !== w || P.h !== h) seed(P, w, h); }

function fillEllipse(ctx, cx, cy, rx, ry) { ctx.beginPath(); ctx.ellipse(cx-rx, cy-ry, rx*2, ry*2); ctx.fill(); }
function fillCircle(ctx, cx, cy, r) { ctx.beginPath(); ctx.arc(cx, cy, r, 0, 6.283); ctx.fill(); }

// Derived scene values, computed once per input change and read by every layer.
function scene(h, inp) {
    var base = inp.base;
    // Warp into the reference frame once; sun arc, gradient and day/night all read it.
    var hour = warp(inp.hour, inp.sr, inp.ss);
    // Seasonal solar geometry from place + date: noon sun height and hue cast.
    var sol = (isFinite(inp.lat) && isFinite(inp.doy)) ? solar(inp.doy, inp.lat) : { altScale: 1, season: 0 };
    var sev = SEV[base] || 0, dl = daylight(hour);
    // Wind -> horizontal drift factor, +right. ~1 at 30 km/h from due west; sign
    // flips for an easterly. windDir is the meteorological direction wind blows FROM.
    var windX = -Math.sin((inp.windDir || 0) * Math.PI / 180) * ((inp.wind || 0) / 30);
    // Cloud count from actual cloud_cover, floored to the base's character so rain/thunder
    // stay heavy and a "clear" sky can still carry a wisp at high cover.
    var cloudFloor = ({ clear:0, partly:2, cloudy:4, fog:2, rain:5, snow:4, thunder:6 }[base] || 0);
    // Rain count from precip mm: a floor keeps a rain/thunder code visible even at 0 mm,
    // and it climbs with intensity toward a downpour.
    var rainFloor = base === "thunder" ? 90 : 45;
    var raining = base === "rain" || base === "thunder";
    return {
        base: base, hour: hour, sev: sev, dl: dl, altScale: sol.altScale,
        sky: grade(tintSeason(skyAt(hour), sol.season), sev, base),
        horizonPix: h * 0.68,
        moon: inp.moon || 0,
        starAlpha: (1 - dl) * (1 - sev * 0.7),
        cloudCount: clamp(Math.max(Math.round((inp.cloud || 0) * 9), cloudFloor), 0, 9),
        // Drift scales with wind and keeps the cloud's own base speed as a calm floor.
        driftMag: 0.4 + Math.abs(windX) * 1.6,
        driftDir: windX < 0 ? -1 : 1,
        birds: (base === "clear" || base === "partly") && isDay(hour) && sev < 0.2,
        raining: raining,
        rainCount: raining ? Math.round(clamp(rainFloor + (inp.precip || 0) * 26, rainFloor, 170)) : 0,
        slant: 1.5 + windX * 4,   // horizontal advance per frame, signed by wind
        snowing: base === "snow",
        snowCount: Math.round(clamp(30 + (inp.snow || 0) * 40, 30, 95)),
        gust: windX * 1.2,   // steady sideways push from wind, over the gentle sway
        fogging: base === "fog",
        storming: base === "thunder"
    };
}

// Sky gradient + sun/moon.
function paintBack(ctx, w, h, S) {
    ctx.clearRect(0, 0, w, h);
    var g = ctx.createLinearGradient(0, 0, 0, h);
    skyStops(g, S.sky.top, S.sky.mid, 0, 0.52);
    skyStops(g, S.sky.mid, S.sky.hor, 0.52, 1);
    ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
    drawBody(ctx, S.hour, S.base, w, h, S.horizonPix, S.sev, S.dl, S.altScale, S.moon);
}


// Hills in front of the clouds.
function paintHills(ctx, w, h, S, P) {
    ensure(P, w, h);
    ctx.clearRect(0, 0, w, h);
    drawHills(ctx, w, h, S.sky.hor, S.dl, P);
}


// Edge darkening over everything. Size alone shapes it.
function paintVignette(ctx, w, h) {
    ctx.clearRect(0, 0, w, h);
    var vg = ctx.createRadialGradient(w/2, h*0.44, h*0.3, w/2, h*0.5, h*0.95);
    vg.addColorStop(0, "rgba(0,0,0,0)"); vg.addColorStop(1, "rgba(0,0,0,0.24)");
    ctx.fillStyle = vg; ctx.fillRect(0, 0, w, h);
}

function drawBody(ctx, hour, base, w, h, horizonPix, sev, dl, altScale, phase) {
    var topY = h * 0.13;
    if (isDay(hour)) {
        // arc: time-of-day, 0 at rise/set and 1 at noon; drives disc size + warmth.
        // alt: seasonal height, arc scaled by the noon-sun fraction (low in winter).
        var p = clamp((hour-SUNR)/(SUNS-SUNR),0,1);
        var arc = Math.sin(p*Math.PI), low = 1 - arc, alt = arc * (altScale == null ? 1 : altScale);
        var cx = p*w, cy = horizonPix - alt*(horizonPix-topY), R = (h*0.055) + (h*0.03)*low, a = clamp(1-sev*0.9,0,1);
        if (a <= 0.03) return;
        var discA = a * (1 - sev);
        var core = lc([255,248,220],[255,168,96], low*0.9);
        var gl = ctx.createRadialGradient(cx,cy,R*0.4,cx,cy,R*5.5);
        gl.addColorStop(0, rgba(core,0.5*a)); gl.addColorStop(0.4, rgba(lc(core,[255,150,70],0.6),0.2*a)); gl.addColorStop(1, rgba(core,0));
        ctx.fillStyle = gl; fillCircle(ctx, cx, cy, R*5.5);
        ctx.fillStyle = rgba(core, discA); fillCircle(ctx, cx, cy, R);
    } else {
        var nh = hour < SUNR ? hour+24 : hour, np = clamp((nh-SUNS)/((SUNR+24)-SUNS),0,1), na = Math.sin(np*Math.PI);
        var mx = np*w, my = horizonPix - na*(horizonPix-topY), R2 = h*0.05, a2 = 1 - sev*0.55;
        var moon = [236,240,250];
        // Glow tracks illumination: a full moon halos brightly, a new moon barely.
        var litFrac = (1 - Math.cos(2*Math.PI*(phase||0))) / 2;
        var hg = ctx.createRadialGradient(mx,my,R2*0.6,mx,my,R2*3.2);
        hg.addColorStop(0, rgba(moon, 0.28*a2*(0.15+0.85*litFrac))); hg.addColorStop(1, rgba(moon,0));
        ctx.fillStyle = hg; fillCircle(ctx, mx, my, R2*3.2);
        ctx.fillStyle = rgba(moon,a2); fillCircle(ctx, mx, my, R2);
        ctx.fillStyle = rgba(shade(moon,0.86), a2*0.6);
        fillCircle(ctx, mx-R2*0.3, my-R2*0.2, R2*0.16);
        fillCircle(ctx, mx+R2*0.25, my+R2*0.1, R2*0.12);
        fillCircle(ctx, mx-R2*0.05, my+R2*0.35, R2*0.1);
        // Real phase: sky-colored shadow over the unlit part, so it blends into night.
        var sky = grade(skyAt(hour), sev, base);
        drawMoonShadow(ctx, mx, my, R2, phase || 0, rgba(sky.mid, 1));
    }
}

// Cover the moon's unlit part with the sky color. phase 0..1 (0/1 new, 0.5 full).
// The terminator is an ellipse: at each row its x is cos(2*pi*phase) * half-width,
// so the lit lune grows from new to full and the shadow sits on the trailing side.
function drawMoonShadow(ctx, cx, cy, R, phase, style) {
    if ((1 - Math.cos(2 * Math.PI * phase)) / 2 >= 0.985) return;  // full moon: nothing to hide
    var c = Math.cos(2 * Math.PI * phase), waxing = phase < 0.5;
    ctx.fillStyle = style;
    var step = Math.max(1, R / 18);
    for (var y = -R; y <= R; y += step) {
        var wd = Math.sqrt(Math.max(0, R * R - y * y));
        var xL = waxing ? -wd : -c * wd, xR = waxing ? c * wd : wd;
        if (xR > xL) ctx.fillRect(cx + xL, cy + y - step * 0.5, xR - xL, step + 1);
    }
}

function cloudColors(S) {
    var day = [240,244,251], night = [92,102,132];
    var base0 = lc(night, day, S.dl), storm = (S.base === "rain" || S.base === "thunder") ? [74,82,104] : [150,156,170];
    var col = lc(base0, storm, S.sev*0.92);
    return { col: col, hi: lc(col, [255,255,255], 0.2+S.dl*0.12), under: shade(col, 0.82), op: { clear:0.62, partly:0.8 }[S.base] || 0.96 };
}
// One cloud into its own texture. The box spans 100s x 43s with the puff centre
// at (50s, 19s), the extent of the widest and tallest ellipses below plus a pixel.
function paintPuff(ctx, w, h, s, c) {
    ctx.clearRect(0, 0, w, h);
    var cx = 50 * s, cy = 19 * s;
    ctx.save(); ctx.globalAlpha = c.op;
    var body = [[0,4,1.0],[-22,6,0.72],[22,6,0.72],[-38,10,0.5],[38,10,0.5]], i;
    ctx.fillStyle = rgba(c.under);
    for (i = 0; i < body.length; i++) fillEllipse(ctx, cx+body[i][0]*s, cy+(body[i][1]+3)*s, body[i][2]*22*s, body[i][2]*16*s);
    ctx.fillStyle = rgba(c.col);
    for (i = 0; i < body.length; i++) fillEllipse(ctx, cx+body[i][0]*s, cy+body[i][1]*s, body[i][2]*22*s, body[i][2]*17*s);
    var top = [[-6,-6,0.7],[12,-8,0.62],[-20,-2,0.5],[0,-11,0.5]];
    ctx.fillStyle = rgba(c.hi);
    for (i = 0; i < top.length; i++) fillEllipse(ctx, cx+top[i][0]*s, cy+top[i][1]*s, top[i][2]*20*s, top[i][2]*15*s);
    ctx.restore();
}

function drawHills(ctx, w, h, hor, dl, P) {
    var warm = clamp((hor[0]-hor[2]-30)/150, 0, 0.6);
    for (var li = 0; li < P.hills.length; li++) {
        var L = P.hills[li], col = lc(shade(hor,L.sh), [16,20,34], (1-dl)*0.5+0.12);
        ctx.fillStyle = rgba(col); ctx.beginPath(); ctx.moveTo(0, h);
        var pts = [];
        for (var xx = 0; xx <= w; xx += 6) {
            var y = h*L.by + Math.sin(xx*L.f1+L.p1)*h*L.amp + Math.sin(xx*L.f2+L.p2)*h*L.amp*0.4;
            pts.push([xx,y]); ctx.lineTo(xx, y);
        }
        ctx.lineTo(w, h); ctx.closePath(); ctx.fill();
        if (warm > 0.05 && li >= 1) {
            ctx.strokeStyle = rgba([255,214,150], warm*(li===2?0.5:0.3)); ctx.lineWidth = 1.6; ctx.lineCap = "round";
            ctx.beginPath();
            for (var k = 0; k < pts.length; k++) { if (k === 0) ctx.moveTo(pts[k][0],pts[k][1]); else ctx.lineTo(pts[k][0],pts[k][1]); }
            ctx.stroke();
        }
    }
}


// One fog band, 30px tall, the ellipse 18px wider than the scene on each side
// so the sway never bares an edge.
function paintFog(ctx, w, h, i) {
    ctx.clearRect(0, 0, w, h);
    var g = ctx.createLinearGradient(0, 0, w, 0);
    g.addColorStop(0, "rgba(222,226,232,0)"); g.addColorStop(0.5, "rgba(222,226,232," + (0.3-i*0.05) + ")"); g.addColorStop(1, "rgba(222,226,232,0)");
    ctx.fillStyle = g; fillEllipse(ctx, w/2, h/2, (w-36)*0.62, 15);
}
// One bird in a 10x10 box; fl is the wing lift in px, -3..3.
function paintBird(ctx, fl) {
    ctx.clearRect(0, 0, 10, 10);
    ctx.strokeStyle = "rgba(30,36,50,0.5)"; ctx.lineWidth = 1.6; ctx.lineCap = "round";
    ctx.beginPath(); ctx.moveTo(1, 5); ctx.lineTo(5, 4-fl); ctx.lineTo(9, 5); ctx.stroke();
}
// Glow is stacked wide strokes, widest and faintest first; a blur per frame
// would cost more than the rest of the scene.
var BOLT_PASS = [[14,[255,246,180],0.10], [9,[255,246,180],0.18], [4,[255,255,255],1], [1.6,[180,210,255],1]];

function strike(w, h, P) {
    var x = Math.random()*w*0.6 + w*0.2, y = h*0.14, pts = [[x,y]];
    for (var k = 0; k < 4; k++) { x += (Math.random()-0.5)*w*0.06; y += h*0.14; pts.push([x,y]); }
    P.boltPts = pts.map(function (p) { return Qt.point(p[0], p[1]); }); P.flash = 1;
}

// Advances flash decay and bolt timing on wall-clock time. Returns true on a new strike,
// whose path then stays fixed for the strike's life: re-rolling it per frame reads as static.
function stepStorm(P, w, h) {
    ensure(P, w, h);
    // Clamp covers menu reopen after a long close, where P carries a stale timestamp.
    var now = Date.now(), dt = P.t ? clamp(now - P.t, 0, 120) : 33;
    P.t = now;
    if (P.flash > 0) {
        P.flash -= dt / FLASH_MS;
        return false;
    }
    P.nextBolt -= dt;
    if (P.nextBolt > 0) return false;
    P.nextBolt = BOLT_GAP_MS + Math.random()*BOLT_JITTER_MS;
    strike(w, h, P);
    return true;
}
