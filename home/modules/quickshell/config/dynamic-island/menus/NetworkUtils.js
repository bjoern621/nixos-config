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

// Shorten NetworkManager's flag list to one label. "WPA1 WPA2" -> "WPA2".
function securityLabel(security) {
    if (!isSecured(security))
        return "Offen";
    const s = security.toUpperCase();
    if (s.indexOf("WPA3") >= 0 || s.indexOf("SAE") >= 0)
        return "WPA3";
    if (s.indexOf("WPA2") >= 0)
        return "WPA2";
    if (s.indexOf("WPA") >= 0)
        return "WPA";
    if (s.indexOf("WEP") >= 0)
        return "WEP";
    return "Gesichert";
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

// Fields: IN-USE,SIGNAL,SECURITY,FREQ,SSID
function parseWifiScan(text) {
    const out = [];
    const lines = _lines(text);
    for (let i = 0; i < lines.length; i++) {
        const f = splitTerse(lines[i]);
        if (f.length < 5)
            continue;
        const ssid = f[4];
        if (!ssid.length)
            continue; // hidden / empty
        out.push({
            ssid: ssid,
            inUse: f[0] === "*",
            signal: parseInt(f[1], 10) || 0,
            security: f[2],
            freq: f[3]
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

// `nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,GENERAL.HWADDR device show <dev>`
// yields `KEY:VALUE` lines; IP4.DNS repeats with [n] suffixes.
function parseDeviceDetail(text) {
    const detail = {
        ip: "",
        gateway: "",
        dns: [],
        mac: ""
    };
    const lines = _lines(text);
    for (let i = 0; i < lines.length; i++) {
        const idx = lines[i].indexOf(":");
        if (idx < 0)
            continue;
        const key = lines[i].substring(0, idx);
        const value = lines[i].substring(idx + 1);
        if (!value.length || value === "--")
            continue;
        if (key.indexOf("IP4.ADDRESS") === 0 && !detail.ip)
            detail.ip = value; // "192.168.1.5/24"
        else if (key.indexOf("IP4.GATEWAY") === 0)
            detail.gateway = value;
        else if (key.indexOf("IP4.DNS") === 0)
            detail.dns.push(value);
        else if (key.indexOf("GENERAL.HWADDR") === 0)
            detail.mac = value;
    }
    return detail;
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
        const prev = bytop[n.ssid];
        if (prev) {
            if (n.inUse)
                prev.inUse = true;
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
            security: n.security
        };
    }

    const rows = [];
    for (const ssid in bytop) {
        const n = bytop[ssid];
        const saved = savedByName[ssid];
        rows.push({
            ssid: ssid,
            signal: n.signal,
            level: signalLevel(n.signal),
            secured: isSecured(n.security),
            securityLabel: securityLabel(n.security),
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

// Active wired connection, if any ethernet profile is up.
function findEthernet(connections) {
    for (let i = 0; i < connections.length; i++) {
        const c = connections[i];
        if (c.type === "ethernet" && c.active) {
            return {
                name: c.name,
                uuid: c.uuid,
                device: c.device
            };
        }
    }
    return null;
}

// Device carrying the active wifi/ethernet connection, for the detail read.
function activeDevice(connections) {
    for (let i = 0; i < connections.length; i++) {
        const c = connections[i];
        if (c.active && (c.type === "wifi" || c.type === "ethernet") && c.device.length)
            return c.device;
    }
    return "";
}
