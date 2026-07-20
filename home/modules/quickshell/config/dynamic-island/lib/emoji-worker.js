// WorkerScript backend for EmojiPicker.
// Off the UI thread: holds the parsed emoji index, answers fuzzy queries with
// the shared fzf port. Per-keystroke scoring of the full dataset never blocks
// rendering.
//
// Messages in:
//   { type: "load",  text, fzfUrl }
//   { type: "query", query, group, maxResults }        query pre-lower-cased
// Messages out:
//   { type: "loaded", ok, count, groups, error }
//   { type: "result", items }                          items: [{ c, n, k }]
//
// fzfUrl arrives resolved from the main thread (Qt.resolvedUrl): a worker's own
// base URL is not the source directory, so a relative Qt.include misses fzf.js.
// The main thread coalesces so only one query is ever in flight; the worker
// need not track sequence numbers.

var ready = false;
var dataset = [];

WorkerScript.onMessage = function (msg) {
    if (msg.type === "load") {
        try {
            if (!ready) {
                Qt.include(msg.fzfUrl);
                ready = (typeof scoreLower === "function");
                if (!ready)
                    throw new Error("fzf.js include failed");
            }
            var data = JSON.parse(msg.text);
            var src = data.emojis || [];
            var out = new Array(src.length);
            for (var i = 0; i < src.length; i++) {
                var e = src[i];
                // Match name+keywords; cache lower-cased once, re-scored per keystroke.
                var combined = e.k ? (e.n + " " + e.k) : e.n;
                out[i] = { c: e.c, n: e.n, k: e.k || "", g: e.g, lower: combined.toLowerCase() };
            }
            dataset = out;
            WorkerScript.sendMessage({ type: "loaded", ok: true, count: dataset.length, groups: data.groups || [] });
        } catch (err) {
            WorkerScript.sendMessage({ type: "loaded", ok: false, error: String(err) });
        }
        return;
    }

    if (msg.type === "query") {
        if (!ready) {
            WorkerScript.sendMessage({ type: "result", items: [] });
            return;
        }
        var q = msg.query;
        var items;
        if (q === "") {
            // No query: selected group, CLDR order.
            items = [];
            for (var gi = 0; gi < dataset.length; gi++) {
                var ge = dataset[gi];
                if (ge.g === msg.group)
                    items.push({ c: ge.c, n: ge.n, k: ge.k });
            }
        } else {
            var scored = [];
            for (var si = 0; si < dataset.length; si++) {
                var se = dataset[si];
                var s = scoreLower(se.lower, se.lower, q);
                if (s > -Infinity)
                    scored.push({ e: se, score: s });
            }
            scored.sort(function (a, b) { return b.score - a.score; });
            var limit = Math.min(scored.length, msg.maxResults);
            items = new Array(limit);
            for (var oi = 0; oi < limit; oi++) {
                var oe = scored[oi].e;
                items[oi] = { c: oe.c, n: oe.n, k: oe.k };
            }
        }
        WorkerScript.sendMessage({ type: "result", items: items });
    }
};
