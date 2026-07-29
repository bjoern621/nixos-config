.pragma library

// Weather parsing + presentation, shared by WeatherService (parse) and
// WeatherWidget (describe). No QML types, so it stays a plain library.

// IP-geolocation JSON -> { ok, lat, lon, city }. Handles ipwho.is (numbers) and
// geojs (strings) alike via parseFloat. Rate-limited or error responses lack a
// finite lat/lon -> ok:false.
function parseLocation(jsonText) {
    try {
        var d = JSON.parse(jsonText);
        var lat = parseFloat(d.latitude), lon = parseFloat(d.longitude);
        if (!isFinite(lat) || !isFinite(lon))
            return { ok: false };
        return { ok: true, lat: lat, lon: lon, city: d.city || "" };
    } catch (e) {
        return { ok: false };
    }
}

// Open-Meteo forecast -> current block + a rolling 24h window from the current
// hour. Times are local wall-clock (timezone=auto). forecast_days=2 gives ~48
// hourly slots; the window is sliced from the slot matching current.time, so the
// timeline runs now .. now+24h and crosses midnight into tomorrow.
// day[k] = { hour, temp, code, isDay, base, cloud, precip, snow, wind, windDir };
// k is hours from the window start, hour is that slot's local clock hour (0..23).
// Missing slots back/forward fill so the ribbon and scene never see a hole.
function parseForecast(jsonText) {
    try {
        var d = JSON.parse(jsonText);
        var cur = d.current || {};
        var h = d.hourly || {};
        var times = h.time || [];
        var n = times.length;

        if (typeof cur.temperature_2m !== "number")
            return { ok: false };

        var ct = cur.time || "";
        var startHour = parseInt(ct.substring(11, 13), 10);
        if (!isFinite(startHour)) startHour = 12;
        // Window start = hourly slot sharing current.time's date+hour ("...THH").
        var startIdx = 0, key = ct.substring(0, 13);
        for (var s = 0; s < n; s++) { if (times[s].substring(0, 13) === key) { startIdx = s; break; } }

        var k, day = [];
        for (k = 0; k < 24; k++) {
            var i = startIdx + k;
            day.push(i < n ? _slot(h, i, (startHour + k) % 24) : null);
        }
        // forward then backward fill any missing slot from its nearest neighbour
        var last = null;
        for (k = 0; k < 24; k++) { if (day[k]) last = day[k]; else if (last) day[k] = _fillSlot(last, (startHour + k) % 24); }
        for (k = 23; k >= 0; k--) { if (day[k]) last = day[k]; else if (last) day[k] = _fillSlot(last, (startHour + k) % 24); }

        var curHour = ct ? (parseInt(ct.substring(11, 13), 10) + parseInt(ct.substring(14, 16), 10) / 60) : 12;

        // daily.sunrise/sunset: local ISO ["YYYY-MM-DDTHH:MM", ...] (timezone=auto).
        // [0] is today; null when the block is absent so the caller keeps its fallback.
        var dly = d.daily || {};
        var sunriseHour = _hourOf(dly.sunrise && dly.sunrise[0]);
        var sunsetHour = _hourOf(dly.sunset && dly.sunset[0]);

        return {
            ok: true,
            currentTemp: Math.round(cur.temperature_2m),
            currentCode: cur.weather_code,
            currentIsDay: cur.is_day === 1,
            currentHour: curHour,
            sunriseHour: sunriseHour,
            sunsetHour: sunsetHour,
            windowStartHour: startHour,
            day: day
        };
    } catch (e) {
        return { ok: false };
    }
}
// Hourly index i -> slot object. Missing numeric fields default to 0; cloud is a
// 0..1 fraction (Open-Meteo reports percent), precip in mm, snow in cm, wind km/h.
function _slot(h, i, hr) {
    var code = (h.weather_code || [])[i];
    function num(arr) { var v = (h[arr] || [])[i]; return (typeof v === "number") ? v : 0; }
    return {
        hour: hr,
        temp: Math.round(num("temperature_2m")),
        code: code,
        isDay: (h.is_day || [])[i] === 1,
        base: sceneBase(code),
        cloud: _clamp01(num("cloud_cover") / 100),
        precip: num("precipitation"),
        snow: num("snowfall"),
        wind: num("wind_speed_10m"),
        windDir: num("wind_direction_10m")
    };
}
function _fillSlot(src, hr) {
    return { hour: hr, temp: src.temp, code: src.code, isDay: src.isDay, base: src.base,
             cloud: src.cloud, precip: src.precip, snow: src.snow, wind: src.wind, windDir: src.windDir };
}

// Local ISO "YYYY-MM-DDTHH:MM" -> fractional local hour, or null on bad input.
function _hourOf(iso) {
    if (typeof iso !== "string" || iso.length < 16)
        return null;
    var hh = parseInt(iso.substring(11, 13), 10), mm = parseInt(iso.substring(14, 16), 10);
    if (!isFinite(hh) || !isFinite(mm))
        return null;
    return hh + mm / 60;
}

// WMO weather code -> scene base condition (drives the sky illustration).
// Drizzle folds into rain visuals; mainly-clear folds into clear.
function sceneBase(code) {
    code = Number(code);
    if (code === 0 || code === 1) return "clear";
    if (code === 2) return "partly";
    if (code === 3) return "cloudy";
    if (code === 45 || code === 48) return "fog";
    if (code >= 51 && code <= 57) return "rain";
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return "rain";
    if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow";
    if (code >= 95) return "thunder";
    return "cloudy";
}

// Timeline swatch per condition: [day RGB, night RGB]. Every condition carries a
// night tone, darker and blue-shifted, so night reads as night for all of them,
// not only clear/partly. Day tones stay the semantic sky palette.
var _cond = {
    clear:   [[246,185,59],  [40,52,104]],   // sun gold   -> deep starry blue
    partly:  [[243,208,138], [52,60,104]],   // pale gold  -> muted blue
    cloudy:  [[173,176,164], [64,68,82]],     // warm grey  -> dark slate
    fog:     [[196,203,210], [76,82,94]],      // pale grey  -> dim grey-blue
    rain:    [[74,144,217],  [40,70,108]],    // rain blue  -> dark rain blue
    snow:    [[191,227,239], [100,120,146]],   // icy pale   -> cold grey-blue
    thunder: [[128,103,192], [56,48,90]]       // storm purple -> deep violet
};

function _clamp01(v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }
function _mix(a, b, f) { return [a[0]+(b[0]-a[0])*f, a[1]+(b[1]-a[1])*f, a[2]+(b[2]-a[2])*f]; }
function _hex2(n) { n = n < 0 ? 0 : (n > 255 ? 255 : Math.round(n)); var s = n.toString(16); return s.length < 2 ? "0" + s : s; }
function _toHex(c) { return "#" + _hex2(c[0]) + _hex2(c[1]) + _hex2(c[2]); }

// Segment hour -> 0 night .. 1 day. Blends across a short twilight band centered
// on sunrise and sunset so dawn/dusk hours are tinted, not a hard day/night flip.
function daynessAt(hour, sr, ss) {
    if (!(ss > sr)) return 1;
    var tw = 1.0;  // twilight half-width, hours
    var d = hour < (sr + ss) / 2 ? (hour - sr) : (ss - hour);
    return _clamp01(d / (2 * tw) + 0.5);
}

// base + day factor -> timeline swatch. day accepts a bool (is_day) or a 0..1
// dayness; the night and day swatches blend by it. conditionRGB returns the raw
// triple for perceptual blending; conditionColor wraps it as a hex string.
function conditionRGB(base, day) {
    var pair = _cond[base] || _cond.cloudy;
    var f = day === true ? 1 : (day === false ? 0 : _clamp01(day));
    return _mix(pair[1], pair[0], f);
}
function conditionColor(base, day) { return _toHex(conditionRGB(base, day)); }
function rgbHex(c) { return _toHex(c); }

// OKLab perceptual color space (Björn Ottosson). Linear-RGB interpolation between
// two saturated hues passes through a dead grey; OKLab keeps lightness and chroma
// on a natural path, so condition transitions in the timeline stay vivid.
function _srgbLin(c) { c /= 255; return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
function _linSrgb(c) { c = c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055; return c * 255; }
function _toOklab(rgb) {
    var r = _srgbLin(rgb[0]), g = _srgbLin(rgb[1]), b = _srgbLin(rgb[2]);
    var l = Math.cbrt(0.4122214708*r + 0.5363325363*g + 0.0514459929*b);
    var m = Math.cbrt(0.2119034982*r + 0.6806995451*g + 0.1073969566*b);
    var s = Math.cbrt(0.0883024619*r + 0.2817188376*g + 0.6299787005*b);
    return [0.2104542553*l + 0.7936177850*m - 0.0040720468*s,
            1.9779984951*l - 2.4285922050*m + 0.4505937099*s,
            0.0259040371*l + 0.7827717662*m - 0.8086757660*s];
}
function _fromOklab(lab) {
    var L = lab[0], A = lab[1], B = lab[2];
    var l = L + 0.3963377774*A + 0.2158037573*B;
    var m = L - 0.1055613458*A - 0.0638541728*B;
    var s = L - 0.0894841775*A - 1.2914855480*B;
    l = l*l*l; m = m*m*m; s = s*s*s;
    return [_linSrgb( 4.0767416621*l - 3.3077115913*m + 0.2309699292*s),
            _linSrgb(-1.2684380046*l + 2.6097574011*m - 0.3413193965*s),
            _linSrgb(-0.0041960863*l - 0.7034186147*m + 1.7076147010*s)];
}
// Perceptual blend of two RGB triples at fraction f.
function oklabMix(a, b, f) {
    var la = _toOklab(a), lb = _toOklab(b);
    return _fromOklab([la[0]+(lb[0]-la[0])*f, la[1]+(lb[1]-la[1])*f, la[2]+(lb[2]-la[2])*f]);
}

// WMO weather code -> { icon (basename under icons/), label (de) }.
// Day/night only splits clear + partly; every other group shares one glyph.
function describe(code, isDay) {
    code = Number(code);
    if (code === 0)
        return { icon: isDay ? "wx-clear-day" : "wx-clear-night", label: "Klar" };
    if (code === 1)
        return { icon: isDay ? "wx-partly-day" : "wx-partly-night", label: "Überwiegend klar" };
    if (code === 2)
        return { icon: isDay ? "wx-partly-day" : "wx-partly-night", label: "Teils bewölkt" };
    if (code === 3)
        return { icon: "wx-cloudy", label: "Bewölkt" };
    if (code === 45 || code === 48)
        return { icon: "wx-fog", label: "Nebel" };
    if (code >= 51 && code <= 57)
        return { icon: "wx-drizzle", label: "Nieselregen" };
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82))
        return { icon: "wx-rain", label: "Regen" };
    if ((code >= 71 && code <= 77) || code === 85 || code === 86)
        return { icon: "wx-snow", label: "Schnee" };
    if (code >= 95)
        return { icon: "wx-thunder", label: "Gewitter" };
    return { icon: "wx-cloudy", label: "" };
}
