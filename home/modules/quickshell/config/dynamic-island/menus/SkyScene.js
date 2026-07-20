.pragma library

// Stylized weather sky, drawn on a QML Canvas Context2D.
// Layered flat-landscape: 3-stop time-of-day sky, sun/moon behind parallax hills,
// two-tone clouds, stylized rain/snow/fog/lightning. Hour-driven; condition + temp
// come from the forecast. State (particles, frame, flash) lives in a plain object P
// owned by SkyScene.qml; seed(P,w,h) fills it, paint(ctx,w,h,inp,P) advances + draws.
//
// Qt Context2D note: ellipse(x,y,w,h) takes a bounding box, not HTML5's
// (cx,cy,rx,ry,rot,a,b). fillEllipse wraps that. arc() matches HTML5.

var SUNR = 6, SUNS = 20;

function clamp(v, a, b) { return v < a ? a : (v > b ? b : v); }
function lerp(a, b, f) { return a + (b - a) * f; }
function lc(a, b, f) { return [Math.round(lerp(a[0],b[0],f)), Math.round(lerp(a[1],b[1],f)), Math.round(lerp(a[2],b[2],f))]; }
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
    var i, rnd = Math.random;
    P.frame = P.frame || 0; P.flash = 0; P.bolt = 0; P.w = w; P.h = h;
    P.stars = []; for (i = 0; i < 95; i++) P.stars.push({ x:rnd()*w, y:rnd()*h*0.66, r:rnd()*1.1+0.35, tw:rnd()*6.28 });
    P.sparkle = []; for (i = 0; i < 6; i++) P.sparkle.push({ x:rnd()*w, y:rnd()*h*0.5, s:rnd()*2+2.5, tw:rnd()*6.28 });
    P.clouds = []; for (i = 0; i < 9; i++) { var dd = 0.5 + rnd()*0.9; P.clouds.push({ x:rnd()*w, y:h*(0.1+rnd()*0.32), s:dd, v:(0.08+rnd()*0.22)*dd }); }
    P.rain = []; for (i = 0; i < 170; i++) P.rain.push({ x:rnd()*w, y:rnd()*h, l:9+rnd()*11, v:6+rnd()*3.5 });
    P.snow = []; for (i = 0; i < 95; i++) { var ss = rnd(); P.snow.push({ x:rnd()*w, y:rnd()*h, r:1.2+ss*2.6, v:0.5+ss*1.1, d:rnd()*6.28, a:0.5+rnd()*0.5 }); }
    P.birds = []; for (i = 0; i < 3; i++) P.birds.push({ x:rnd()*w, y:h*(0.18+rnd()*0.2), v:0.25+rnd()*0.2, ph:rnd()*6.28 });
    P.hills = [
        { by:0.70, amp:0.045, f1:0.010, p1:rnd()*6.28, f2:0.021, p2:rnd()*6.28, sh:0.74 },
        { by:0.80, amp:0.060, f1:0.008, p1:rnd()*6.28, f2:0.019, p2:rnd()*6.28, sh:0.52 },
        { by:0.90, amp:0.075, f1:0.006, p1:rnd()*6.28, f2:0.015, p2:rnd()*6.28, sh:0.32 }
    ];
}

function fillEllipse(ctx, cx, cy, rx, ry) { ctx.beginPath(); ctx.ellipse(cx-rx, cy-ry, rx*2, ry*2); ctx.fill(); }
function fillCircle(ctx, cx, cy, r) { ctx.beginPath(); ctx.arc(cx, cy, r, 0, 6.283); ctx.fill(); }

function paint(ctx, w, h, inp, P) {
    if (!P.stars || P.w !== w || P.h !== h) seed(P, w, h);
    P.frame++;
    var base = inp.base, hour = inp.hour, temp = inp.temp;
    var sev = SEV[base] || 0, dl = daylight(hour), sky = grade(skyAt(hour), sev, base);
    var horizonPix = h * 0.68;

    ctx.clearRect(0, 0, w, h);
    var g = ctx.createLinearGradient(0, 0, 0, h);
    g.addColorStop(0, rgba(sky.top)); g.addColorStop(0.52, rgba(sky.mid)); g.addColorStop(1, rgba(sky.hor));
    ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);

    // stars + sparkles
    var sa = (1 - dl) * (1 - sev * 0.7);
    if (sa > 0.03) {
        for (var i = 0; i < P.stars.length; i++) {
            var st = P.stars[i], tw = 0.5 + 0.5 * Math.sin(P.frame*0.05 + st.tw);
            ctx.fillStyle = rgba([255,255,255], sa*tw*0.85); fillCircle(ctx, st.x, st.y, st.r);
        }
        for (i = 0; i < P.sparkle.length; i++) {
            var sp = P.sparkle[i], t2 = 0.4 + 0.6 * Math.sin(P.frame*0.06 + sp.tw);
            spark(ctx, sp.x, sp.y, sp.s*(0.7+t2*0.5), sa*t2);
        }
    }

    drawBody(ctx, hour, base, w, h, horizonPix, sev, dl);
    drawClouds(ctx, base, w, h, sev, dl, P);
    if ((base === "clear" || base === "partly") && isDay(hour) && sev < 0.2) drawBirds(ctx, w, h, P);
    drawHills(ctx, w, h, sky.hor, dl, P);
    if (base === "rain" || base === "thunder") drawRain(ctx, w, h, base === "thunder" ? 150 : 130, P);
    if (base === "snow") drawSnow(ctx, w, h, P);
    if (base === "fog") drawFog(ctx, w, h, horizonPix, P);
    if (base === "thunder") drawStorm(ctx, w, h, P);

    var vg = ctx.createRadialGradient(w/2, h*0.44, h*0.3, w/2, h*0.5, h*0.95);
    vg.addColorStop(0, "rgba(0,0,0,0)"); vg.addColorStop(1, "rgba(0,0,0,0.24)");
    ctx.fillStyle = vg; ctx.fillRect(0, 0, w, h);
}

function spark(ctx, cx, cy, s, a) {
    ctx.save(); ctx.globalAlpha = clamp(a,0,1); ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 1.3; ctx.lineCap = "round";
    ctx.beginPath(); ctx.moveTo(cx-s,cy); ctx.lineTo(cx+s,cy); ctx.moveTo(cx,cy-s); ctx.lineTo(cx,cy+s); ctx.stroke();
    ctx.fillStyle = "rgba(255,255,255," + (a*0.6).toFixed(2) + ")"; fillCircle(ctx, cx, cy, 1.1); ctx.restore();
}

function drawBody(ctx, hour, base, w, h, horizonPix, sev, dl) {
    var topY = h * 0.13;
    if (isDay(hour)) {
        var p = clamp((hour-SUNR)/(SUNS-SUNR),0,1), alt = Math.sin(p*Math.PI), low = 1 - alt;
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
        var hg = ctx.createRadialGradient(mx,my,R2*0.6,mx,my,R2*3.2);
        hg.addColorStop(0, rgba(moon,0.28*a2)); hg.addColorStop(1, rgba(moon,0));
        ctx.fillStyle = hg; fillCircle(ctx, mx, my, R2*3.2);
        ctx.fillStyle = rgba(moon,a2); fillCircle(ctx, mx, my, R2);
        ctx.fillStyle = rgba(shade(moon,0.86), a2*0.6);
        fillCircle(ctx, mx-R2*0.3, my-R2*0.2, R2*0.16);
        fillCircle(ctx, mx+R2*0.25, my+R2*0.1, R2*0.12);
        fillCircle(ctx, mx-R2*0.05, my+R2*0.35, R2*0.1);
        var sky = grade(skyAt(hour), sev, base);
        ctx.fillStyle = rgba(sky.mid, 1); fillCircle(ctx, mx+R2*0.55, my-R2*0.25, R2*0.96);
    }
}

function drawClouds(ctx, base, w, h, sev, dl, P) {
    var counts = { clear:2, partly:4, cloudy:7, fog:3, rain:7, snow:6, thunder:8 };
    var n = counts[base] || 0;
    var day = [240,244,251], night = [92,102,132];
    var base0 = lc(night, day, dl), storm = (base === "rain" || base === "thunder") ? [74,82,104] : [150,156,170];
    var col = lc(base0, storm, sev*0.92), hi = lc(col, [255,255,255], 0.2+dl*0.12), under = shade(col, 0.82);
    var opac = { clear:0.62, partly:0.8 }[base] || 0.96;
    for (var i = 0; i < n && i < P.clouds.length; i++) {
        var c = P.clouds[i]; c.x += c.v; if (c.x > w + 90*c.s) c.x = -90*c.s;
        puff(ctx, c.x, c.y, c.s*(h/200), col, hi, under, opac);
    }
}
function puff(ctx, cx, cy, s, col, hi, under, op) {
    ctx.save(); ctx.globalAlpha = op;
    var body = [[0,4,1.0],[-22,6,0.72],[22,6,0.72],[-38,10,0.5],[38,10,0.5]], i;
    ctx.fillStyle = rgba(under);
    for (i = 0; i < body.length; i++) fillEllipse(ctx, cx+body[i][0]*s, cy+(body[i][1]+3)*s, body[i][2]*22*s, body[i][2]*16*s);
    ctx.fillStyle = rgba(col);
    for (i = 0; i < body.length; i++) fillEllipse(ctx, cx+body[i][0]*s, cy+body[i][1]*s, body[i][2]*22*s, body[i][2]*17*s);
    var top = [[-6,-6,0.7],[12,-8,0.62],[-20,-2,0.5],[0,-11,0.5]];
    ctx.fillStyle = rgba(hi);
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

function drawRain(ctx, w, h, n, P) {
    n = Math.min(n, P.rain.length); ctx.lineCap = "round";
    for (var i = 0; i < n; i++) {
        var d = P.rain[i]; d.y += d.v; d.x += 1.5; if (d.y > h*0.96) { d.y = -10; d.x = Math.random()*w; } if (d.x > w) d.x -= w;
        var a = 0.35 + (d.l-9)/11*0.4; ctx.strokeStyle = "rgba(200,222,246," + a.toFixed(2) + ")"; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(d.x, d.y); ctx.lineTo(d.x-2.6, d.y+d.l); ctx.stroke();
    }
}
function drawSnow(ctx, w, h, P) {
    for (var i = 0; i < P.snow.length; i++) {
        var f = P.snow[i]; f.y += f.v; f.x += Math.sin(P.frame*0.02+f.d)*0.7; if (f.y > h*0.97) { f.y = -6; f.x = Math.random()*w; }
        ctx.fillStyle = "rgba(255,255,255," + f.a.toFixed(2) + ")"; fillCircle(ctx, f.x, f.y, f.r);
    }
}
function drawFog(ctx, w, h, hy, P) {
    for (var i = 0; i < 4; i++) {
        var y = hy - 40 + i*20, off = Math.sin(P.frame*0.012 + i*1.5)*18;
        var g = ctx.createLinearGradient(0, y, w, y);
        g.addColorStop(0, "rgba(222,226,232,0)"); g.addColorStop(0.5, "rgba(222,226,232," + (0.3-i*0.05) + ")"); g.addColorStop(1, "rgba(222,226,232,0)");
        ctx.fillStyle = g; ctx.save(); ctx.translate(off, 0); fillEllipse(ctx, w/2, y, w*0.62, 15); ctx.restore();
    }
}
function drawBirds(ctx, w, h, P) {
    ctx.strokeStyle = "rgba(30,36,50,0.5)"; ctx.lineWidth = 1.6; ctx.lineCap = "round";
    for (var i = 0; i < P.birds.length; i++) {
        var b = P.birds[i]; b.x += b.v; if (b.x > w+20) b.x = -20;
        var fl = Math.sin(P.frame*0.12 + b.ph)*3, s = 4;
        ctx.beginPath(); ctx.moveTo(b.x-s, b.y); ctx.lineTo(b.x, b.y-fl-1); ctx.lineTo(b.x+s, b.y); ctx.stroke();
    }
}
function drawStorm(ctx, w, h, P) {
    if (P.flash <= 0 && (P.frame % 150) < 2) { P.flash = 1; P.bolt = Math.random()*w*0.6 + w*0.2; }
    if (P.flash > 0) {
        ctx.fillStyle = "rgba(255,252,235," + (P.flash*0.42).toFixed(3) + ")"; ctx.fillRect(0, 0, w, h);
        var bx = P.bolt, by = h*0.14, pts = [[bx,by]], k;
        for (k = 0; k < 4; k++) { bx += (Math.random()-0.5)*w*0.06; by += h*0.14; pts.push([bx,by]); }
        ctx.strokeStyle = "rgba(255,255,255," + P.flash.toFixed(3) + ")"; ctx.lineWidth = 4; ctx.lineCap = "round"; ctx.lineJoin = "round";
        ctx.shadowColor = "rgba(255,246,180,0.9)"; ctx.shadowBlur = 16;
        ctx.beginPath(); for (k = 0; k < pts.length; k++) { if (k===0) ctx.moveTo(pts[k][0],pts[k][1]); else ctx.lineTo(pts[k][0],pts[k][1]); } ctx.stroke();
        ctx.shadowBlur = 0; ctx.strokeStyle = "rgba(180,210,255," + P.flash.toFixed(3) + ")"; ctx.lineWidth = 1.6;
        ctx.beginPath(); for (k = 0; k < pts.length; k++) { if (k===0) ctx.moveTo(pts[k][0],pts[k][1]); else ctx.lineTo(pts[k][0],pts[k][1]); } ctx.stroke();
        P.flash -= 0.055;
    }
}
