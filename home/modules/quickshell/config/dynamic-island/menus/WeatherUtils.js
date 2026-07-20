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

// Open-Meteo forecast -> current block + today's 24 hourly slots.
// Times are local wall-clock (timezone=auto); the hour index is a substring, no
// Date parse. With forecast_days=1 the hourly arrays cover today 00:00..23:00.
// day[hour] = { hour, temp, code, isDay, base }; gaps back/forward fill so the
// ribbon and scene never see a hole.
function parseForecast(jsonText) {
    try {
        var d = JSON.parse(jsonText);
        var cur = d.current || {};
        var h = d.hourly || {};
        var times = h.time || [];
        var temps = h.temperature_2m || [];
        var codes = h.weather_code || [];
        var isDay = h.is_day || [];

        if (typeof cur.temperature_2m !== "number")
            return { ok: false };

        var i, day = [];
        for (i = 0; i < 24; i++) day.push(null);
        for (i = 0; i < times.length; i++) {
            var hh = parseInt(times[i].substring(11, 13), 10);
            if (hh >= 0 && hh <= 23)
                day[hh] = { hour: hh, temp: Math.round(temps[i]), code: codes[i], isDay: isDay[i] === 1, base: sceneBase(codes[i]) };
        }
        // forward then backward fill any missing hour from its nearest neighbour
        var last = null;
        for (i = 0; i < 24; i++) { if (day[i]) last = day[i]; else if (last) day[i] = fillFrom(last, i); }
        for (i = 23; i >= 0; i--) { if (day[i]) last = day[i]; else if (last) day[i] = fillFrom(last, i); }

        var ct = cur.time || "";
        var curHour = ct ? (parseInt(ct.substring(11, 13), 10) + parseInt(ct.substring(14, 16), 10) / 60) : 12;

        return {
            ok: true,
            currentTemp: Math.round(cur.temperature_2m),
            currentCode: cur.weather_code,
            currentIsDay: cur.is_day === 1,
            currentHour: curHour,
            day: day
        };
    } catch (e) {
        return { ok: false };
    }
}
function fillFrom(src, hour) {
    return { hour: hour, temp: src.temp, code: src.code, isDay: src.isDay, base: src.base };
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

// Scene base condition -> ribbon segment color (semantic sky palette).
function conditionColor(base, isDay) {
    switch (base) {
    case "clear":   return isDay ? "#f6b93b" : "#3b4b8c";
    case "partly":  return isDay ? "#f3d08a" : "#4a5385";
    case "cloudy":  return "#adb0a4";
    case "fog":     return "#c4cbd2";
    case "rain":    return "#4a90d9";
    case "snow":    return "#bfe3ef";
    case "thunder": return "#8067c0";
    }
    return "#adb0a4";
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
