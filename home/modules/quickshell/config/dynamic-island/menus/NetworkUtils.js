.pragma library

// Stateless nmcli output parsers for the network menu. One engine copy serves
// every importer (.pragma library), unlike a per-component QtObject.
//
// Related files:
// - base/NetworkService.qml (nmcli reads/actions, models, monitor)
// - menus/NetworkMenu.qml (view + password capture)
// - ../network_backend.py (imperative nmcli/rfkill mutations)
//
// Concern: parse `nmcli -t` terse output, shape wifi/vpn/ethernet row models.

// nmcli -t escapes `:` and `\` in values with a backslash.
// Split on unescaped `:` only, then unescape each field.
function splitTerse(line) {
    const fields = [];
    let cur = "";
    for (let i = 0; i < line.length; i++) {
        const ch = line[i];
        if (ch === "\\" && i + 1 < line.length) {
            cur += line[++i];
        } else if (ch === ":") {
            fields.push(cur);
            cur = "";
        } else {
            cur += ch;
        }
    }
    fields.push(cur);
    return fields;
}

function _lines(text) {
    return (text || "").split("\n").filter(l => l.length > 0);
}

// Empty or "--" security column means an open network.
function isSecured(security) {
    const s = (security || "").trim();
    return s.length > 0 && s !== "--";
}

// Shorten NetworkManager's flag list to one label. "WPA2 WPA3" is transition
// mode: AP offers both, each client picks, so the label keeps both.
function securityLabel(security) {
    if (!isSecured(security))
        return "Offen";
    const s = security.toUpperCase();
    const wpa3 = s.indexOf("WPA3") >= 0 || s.indexOf("SAE") >= 0;
    const wpa2 = s.indexOf("WPA2") >= 0;
    if (wpa3 && wpa2)
        return "WPA2/WPA3";
    if (wpa3)
        return "WPA3";
    if (wpa2)
        return "WPA2";
    if (s.indexOf("WPA") >= 0)
        return "WPA";
    if (s.indexOf("WEP") >= 0)
        return "WEP";
    return "Gesichert";
}

// FREQ "5180 MHz" -> band label. 6 GHz starts at 5925 MHz.
function freqBand(freq) {
    const mhz = parseInt(freq, 10) || 0;
    if (mhz >= 5925)
        return "6 GHz";
    if (mhz >= 4900)
        return "5 GHz";
    if (mhz >= 2400)
        return "2,4 GHz";
    return "";
}

// Bands a SSID is visible on. ["2,4 GHz", "5 GHz"] -> "2,4/5 GHz".
function bandsLabel(bands) {
    const order = ["2,4 GHz", "5 GHz", "6 GHz"];
    const present = order.filter(b => bands.indexOf(b) >= 0);
    if (!present.length)
        return "";
    return present.map(b => b.replace(" GHz", "")).join("/") + " GHz";
}

// Signal 0-100 -> 0-3 arc level.
function signalLevel(signal) {
    const s = parseInt(signal, 10) || 0;
    if (s >= 75)
        return 3;
    if (s >= 50)
        return 2;
    if (s >= 25)
        return 1;
    return 0;
}

// nmcli connection TYPE -> menu category.
function normalizeType(type) {
    switch (type) {
    case "802-11-wireless":
        return "wifi";
    case "802-3-ethernet":
    case "ethernet":
        return "ethernet";
    case "vpn":
        return "vpn";
    case "wireguard":
        return "wireguard";
    default:
        return type;
    }
}

// Fields: IN-USE,SIGNAL,SECURITY,FREQ,CHAN,SSID
function parseWifiScan(text) {
    const out = [];
    const lines = _lines(text);
    for (let i = 0; i < lines.length; i++) {
        const f = splitTerse(lines[i]);
        if (f.length < 6)
            continue;
        const ssid = f[5];
        if (!ssid.length)
            continue; // hidden / empty
        out.push({
            ssid: ssid,
            inUse: f[0] === "*",
            signal: parseInt(f[1], 10) || 0,
            security: f[2],
            freq: f[3],
            chan: f[4]
        });
    }
    return out;
}

// Fields: NAME,UUID,TYPE,DEVICE,ACTIVE,AUTOCONNECT
function parseConnections(text) {
    const out = [];
    const lines = _lines(text);
    for (let i = 0; i < lines.length; i++) {
        const f = splitTerse(lines[i]);
        if (f.length < 6)
            continue;
        out.push({
            name: f[0],
            uuid: f[1],
            type: normalizeType(f[2]),
            device: f[3],
            active: f[4] === "yes",
            autoconnect: f[5] === "yes"
        });
    }
    return out;
}

// Fields: STATE,CONNECTIVITY,WIFI  (single line)
function parseGeneral(text) {
    const line = _lines(text)[0] || "";
    const f = splitTerse(line);
    return {
        state: f[0] || "",
        connectivity: f[1] || "",
        wifiEnabled: (f[2] || "") === "enabled"
    };
}

function emptyDetail(device) {
    return {
        device: device || "",
        type: "",
        stateCode: 0,
        state: "unknown",
        connection: "",
        mac: "",
        speed: "",
        ip4: "",
        gateway: "",
        dns: [],
        ip6: ""
    };
}

// NMDeviceState numeric codes. 40-99 span preparing/config/need-auth/ip-check,
// all of which read as "connecting" to the user.
function deviceStateKind(code) {
    if (code >= 100)
        return code >= 110 ? (code === 120 ? "failed" : "disconnecting") : "connected";
    if (code >= 40)
        return "connecting";
    if (code === 30)
        return "disconnected";
    if (code === 20)
        return "unavailable";
    if (code === 10)
        return "unmanaged";
    return "unknown";
}

// `nmcli -t device show` with no device argument dumps every device, one record
// per device. Values are unescaped and may contain `:` (HWADDR, IPv6), so a
// record line splits at its first `:` only. List fields repeat with an [n]
// suffix. A record starts at GENERAL.DEVICE, which nmcli always emits first.
function parseDevices(text) {
    const out = [];
    let cur = null;
    const lines = _lines(text);
    for (let i = 0; i < lines.length; i++) {
        const idx = lines[i].indexOf(":");
        if (idx < 0)
            continue;
        const key = lines[i].substring(0, idx);
        const value = lines[i].substring(idx + 1);
        if (key === "GENERAL.DEVICE") {
            cur = emptyDetail(value);
            out.push(cur);
            continue;
        }
        if (!cur || !value.length || value === "--")
            continue;
        if (key === "GENERAL.TYPE") {
            cur.type = normalizeType(value);
        } else if (key === "GENERAL.STATE") {
            cur.stateCode = parseInt(value, 10) || 0;   // "100 (connected)"
            cur.state = deviceStateKind(cur.stateCode);
        } else if (key === "GENERAL.CONNECTION") {
            cur.connection = value;
        } else if (key === "GENERAL.HWADDR") {
            cur.mac = value;
        } else if (key === "CAPABILITIES.SPEED") {
            if (value !== "unknown")
                cur.speed = value;
        } else if (key.indexOf("IP4.ADDRESS") === 0) {
            if (!cur.ip4)
                cur.ip4 = value; // "192.168.1.5/24"
        } else if (key === "IP4.GATEWAY") {
            cur.gateway = value;
        } else if (key.indexOf("IP4.DNS") === 0) {
            cur.dns.push(value);
        } else if (key.indexOf("IP6.ADDRESS") === 0) {
            // Link-local is always present and never useful; prefer a routable one.
            if (!cur.ip6 && value.indexOf("fe80:") !== 0)
                cur.ip6 = value;
        }
    }
    return out;
}

// Facts shown in a device's detail panel, in display order. Empty values drop
// out. Extension point: one entry here adds the fact to wifi and wired rows both.
function deviceDetailRows(detail) {
    if (!detail)
        return [];
    const rows = [{
        label: "IP",
        value: detail.ip4
    }, {
        label: "Gateway",
        value: detail.gateway
    }, {
        label: "DNS",
        value: (detail.dns || []).join(", ")
    }, {
        label: "IPv6",
        value: detail.ip6
    }, {
        label: "Linkrate",
        value: detail.speed
    }, {
        label: "MAC",
        value: detail.mac
    }, {
        label: "Gerät",
        value: detail.device
    }];
    return rows.filter(r => r.value && r.value.length > 0);
}

// Wifi-link facts prepended to the shared device rows. Band names the one BSS
// the link rides; the list dedupes per SSID, so this is where a dual-band AP
// shows which side carried the association.
function wifiDetailRows(detail, network) {
    const rows = [{
        label: "Band",
        value: network.band.length ? network.band + (network.channel.length ? " · Kanal " + network.channel : "") : ""
    }, {
        label: "Sicherheit",
        value: network.secured ? network.securityLabel : ""
    }];
    return rows.filter(r => r.value.length > 0).concat(deviceDetailRows(detail));
}

// /proc/net/dev: two header lines, then `iface: rx ... tx ...` per interface.
// Column 0 is rx bytes, column 8 tx bytes. One read covers every interface, so
// per-device rates cost no extra process.
function parseProcNetDev(text) {
    const out = {};
    const lines = _lines(text);
    for (let i = 0; i < lines.length; i++) {
        const idx = lines[i].indexOf(":");
        if (idx < 0)
            continue;
        const name = lines[i].substring(0, idx).trim();
        const f = lines[i].substring(idx + 1).trim().split(/\s+/);
        if (!name.length || f.length < 9)
            continue;
        out[name] = {
            rx: parseFloat(f[0]) || 0,
            tx: parseFloat(f[8]) || 0
        };
    }
    return out;
}

// Merge a wifi scan with saved profiles into the row model.
// Dedupe by SSID keeping the strongest signal; carry the in-use / saved flags.
function buildWifiModel(scan, connections) {
    const savedByName = {};
    for (let i = 0; i < connections.length; i++) {
        const c = connections[i];
        if (c.type === "wifi")
            savedByName[c.name] = c;
    }

    const bytop = {};
    for (let i = 0; i < scan.length; i++) {
        const n = scan[i];
        const band = freqBand(n.freq);
        const prev = bytop[n.ssid];
        if (prev) {
            if (band && prev.bands.indexOf(band) < 0)
                prev.bands.push(band);
            if (n.inUse) {
                prev.inUse = true;
                prev.activeBss = n;
            }
            if (n.signal > prev.signal) {
                prev.signal = n.signal;
                prev.security = n.security;
            }
            continue;
        }
        bytop[n.ssid] = {
            ssid: n.ssid,
            inUse: n.inUse,
            signal: n.signal,
            security: n.security,
            bands: band ? [band] : [],
            activeBss: n.inUse ? n : null
        };
    }

    const rows = [];
    for (const ssid in bytop) {
        const n = bytop[ssid];
        const saved = savedByName[ssid];
        // The * scan row is the BSS the link rides. Its freq/security beat the
        // strongest-signal fields: a dual-band AP can offer WPA3 on one band only.
        const bss = n.activeBss;
        rows.push({
            ssid: ssid,
            signal: n.signal,
            level: signalLevel(n.signal),
            secured: isSecured(n.security),
            securityLabel: securityLabel(bss ? bss.security : n.security),
            band: bss ? freqBand(bss.freq) : "",
            channel: bss ? bss.chan : "",
            bandLabel: bandsLabel(n.bands),
            active: n.inUse,
            saved: saved !== undefined,
            savedUuid: saved ? saved.uuid : "",
            autoconnect: saved ? saved.autoconnect : false
        });
    }

    rows.sort((a, b) => {
        if (a.active !== b.active)
            return a.active ? -1 : 1;
        if (a.saved !== b.saved)
            return a.saved ? -1 : 1;
        return b.signal - a.signal;
    });
    return rows;
}

function buildVpnModel(connections) {
    const out = [];
    for (let i = 0; i < connections.length; i++) {
        const c = connections[i];
        if (c.type === "vpn" || c.type === "wireguard") {
            out.push({
                name: c.name,
                uuid: c.uuid,
                kind: c.type === "wireguard" ? "WireGuard" : "VPN",
                active: c.active
            });
        }
    }
    out.sort((a, b) => {
        if (a.active !== b.active)
            return a.active ? -1 : 1;
        return a.name.localeCompare(b.name);
    });
    return out;
}

// `tailscale status --json`. Tailscale is a tun device NetworkManager cannot
// toggle; its real up/down state lives in the daemon. BackendState "Running"
// means up; "Stopped"/"NeedsLogin" mean down. Non-JSON (binary absent) -> not
// available, so no row is shown.
function parseTailscale(text) {
    try {
        const j = JSON.parse(text);
        return {
            available: true,
            up: (j.BackendState || "") === "Running"
        };
    } catch (e) {
        return {
            available: false,
            up: false
        };
    }
}

// `systemctl show -p LoadState -p ActiveState --value wg-quick-wg-wstunnel.service`,
// two lines in that order. LoadState "loaded" means this host carries the unit, so a
// row shows; "not-found" (other hosts) hides it. ActiveState "active" means up.
function parseWgWstunnel(text) {
    const lines = text.trim().split("\n");
    return {
        available: (lines[0] || "").trim() === "loaded",
        up: (lines[1] || "").trim() === "active"
    };
}

// Wired row state. `unavailable` on an ethernet device means no carrier;
// `disconnected` means the cable is in but no profile is up, which is where
// "Trennen" leaves the device (nmcli device disconnect also blocks autoconnect).
function wiredStateLabel(state) {
    switch (state) {
    case "connected":
        return "Verbunden";
    case "connecting":
        return "Verbinde...";
    case "disconnecting":
        return "Trenne...";
    case "disconnected":
        return "Kabel erkannt · nicht verbunden";
    case "unavailable":
        return "Kein Kabel";
    case "failed":
        return "Verbindung fehlgeschlagen";
    default:
        return "Unbekannt";
    }
}

// One row per wired device, not per active connection: several ethernet devices
// (dock, USB adapter, onboard) can each carry an active connection at once, and
// a device outlives its connection, so the row survives "Trennen" and reports
// the link state instead of vanishing. Docker/libvirt taps are unmanaged and
// drop out.
function buildWiredModel(devices, connections) {
    const activeByDevice = {};
    for (let i = 0; i < connections.length; i++) {
        const c = connections[i];
        if (c.active && c.type === "ethernet" && c.device.length)
            activeByDevice[c.device] = c;
    }

    const rows = [];
    for (let i = 0; i < devices.length; i++) {
        const d = devices[i];
        if (d.type !== "ethernet" || d.state === "unmanaged")
            continue;
        const conn = activeByDevice[d.device];
        const connected = d.state === "connected";
        rows.push({
            device: d.device,
            name: d.connection.length ? d.connection : d.device,
            uuid: conn ? conn.uuid : "",
            state: d.state,
            stateLabel: wiredStateLabel(d.state),
            connected: connected,
            // No carrier: nothing to connect to, so the action chip stays hidden.
            plugged: d.state !== "unavailable",
            busy: d.state === "connecting" || d.state === "disconnecting",
            autoconnect: conn ? conn.autoconnect : false,
            detail: d
        });
    }

    rows.sort((a, b) => {
        if (a.connected !== b.connected)
            return a.connected ? -1 : 1;
        if (a.plugged !== b.plugged)
            return a.plugged ? -1 : 1;
        return a.device.localeCompare(b.device);
    });
    return rows;
}
