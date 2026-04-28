.pragma library

const MASK = "****";

function loadSensitiveIds(text) {
    const set = {};
    if (!text) return set;
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const id = lines[i].trim();
        if (id) set[id] = true;
    }
    return set;
}

function shannonEntropy(s) {
    const counts = {};
    for (let i = 0; i < s.length; i++) {
        const c = s.charAt(i);
        counts[c] = (counts[c] || 0) + 1;
    }
    let h = 0;
    const len = s.length;
    for (const c in counts) {
        const p = counts[c] / len;
        h -= p * Math.log(p) / Math.LN2;
    }
    return h;
}

const RE_JWT = /\bey[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/g;
const RE_GH = /\bgh[pousr]_[A-Za-z0-9]{30,}\b/g;
const RE_GL = /\bglpat-[A-Za-z0-9_-]{20,}\b/g;
const RE_BEARER = /\b(Bearer)(\s+)([A-Za-z0-9._\-+/=]{16,})\b/gi;
const RE_KV = /\b(password|passwort|passwd|pwd|secret|token|api[_-]?key|access[_-]?token|auth)(\s*[:=]\s*)(\S+)/gi;
// Excludes '/' and '-' so URLs and Nix store paths don't trip the blob heuristic.
// JWTs (which legitimately contain '.' and '-') are handled by RE_JWT above.
const RE_BLOB = /[A-Za-z0-9+=_]{32,}/g;

function maskEntry(raw, sourceReason) {
    if (raw == null) return { display: "", masked: false, reason: "" };

    if (sourceReason) {
        return { display: MASK, masked: true, reason: sourceReason };
    }

    let masked = false;
    let reason = "";
    let s = raw;

    s = s.replace(RE_JWT, function () { masked = true; reason = reason || "JWT erkannt"; return MASK; });
    s = s.replace(RE_GH, function () { masked = true; reason = reason || "GitHub-Token erkannt"; return MASK; });
    s = s.replace(RE_GL, function () { masked = true; reason = reason || "GitLab-Token erkannt"; return MASK; });
    s = s.replace(RE_BEARER, function (_m, kw, sp) { masked = true; reason = reason || "Bearer-Token erkannt"; return kw + sp + MASK; });
    s = s.replace(RE_KV, function (_m, key, sep) { masked = true; reason = reason || ("Schlüssel-Wert-Paar (" + key + ")"); return key + sep + MASK; });

    s = s.replace(RE_BLOB, function (m) {
        // 4.5 bits/char keeps ~32-char hex hashes (Nix store, git sha) below the
        // threshold while still catching base64/random secrets that use a wider alphabet.
        if (shannonEntropy(m) > 4.5) {
            masked = true;
            reason = reason || "Hohe Entropie";
            return MASK;
        }
        return m;
    });

    return { display: s, masked: masked, reason: reason };
}
