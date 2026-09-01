pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Brings an app's window forward, switching workspace when it sits on another.
// Wayland grants no self-raise.
// MPRIS Raise and a notification's default action reach the client,
// but the activation it then asks for carries no token and Hyprland drops it,
// so the focus has to be dispatched from the shell.
Singleton {
    id: root

    // Window-class forms for one name.
    // Selector text becomes Lua source,
    // so anything outside the identifier set is dropped.
    // The hyphen-joined form catches an app whose class spells a two-word name
    // ("Google Chrome" against "google-chrome").
    // Dot is an RE2 wildcard, so it survives the strip escaped.
    function _regexLiterals(name) {
        const raw = (name ?? "").toString().trim();
        const forms = [raw.replace(/[^A-Za-z0-9._-]/g, ""), raw.replace(/[^A-Za-z0-9._-]+/g, "-")];
        const out = [];
        for (let i = 0; i < forms.length; i++) {
            const literal = forms[i].replace(/\./g, "\\.");
            // Two chars minimum.
            // A one-letter class regex matches half the session.
            if (literal.length >= 2 && out.indexOf(literal) === -1)
                out.push(literal);
        }
        return out;
    }

    function _lookup(selector) {
        return "hl.get_window([[" + selector + "]])";
    }

    // Hyprland's config language is Lua, so a dispatch carries a Lua expression.
    // Word syntax ("focuswindow class:x") is a parse error.
    //
    // Candidates resolve inside Hyprland rather than one dispatch each:
    // a dispatch matching nothing is silent,
    // so a chain of them cannot stop at the first hit.
    // no_op covers all-miss, since focus without a window logs an error.
    //
    // Long brackets carry the selector.
    // The class regex holds backslashes,
    // and a quoted Lua string would eat them as escapes.
    function _dispatchFirst(selectors) {
        if (selectors.length === 0)
            return false;
        const chain = selectors.map(root._lookup).join(" or ");
        Hyprland.dispatch("(function() local w = " + chain + "; if w then return hl.dsp.focus({ window = w }) end return hl.dsp.no_op() end)()");
        return true;
    }

    // pid, then class.
    // pid names one process,
    // while a class regex can land on an unrelated app's window.
    // names: any window-class candidate (desktop entry id, StartupWMClass, app name).
    function focusApp(pid, names) {
        const selectors = [];

        const numeric = Number(pid);
        if (isFinite(numeric) && numeric > 0)
            selectors.push("pid:" + Math.floor(numeric));

        const classes = [];
        for (let i = 0; i < (names ?? []).length; i++) {
            const literals = root._regexLiterals(names[i]);
            for (let j = 0; j < literals.length; j++) {
                if (classes.indexOf(literals[j]) === -1)
                    classes.push(literals[j]);
            }
        }
        if (classes.length > 0) {
            const alternation = "(?i)^(" + classes.join("|") + ")$";
            selectors.push("class:" + alternation);
            // Electron and Chrome apps map with one class,
            // then report another at runtime.
            selectors.push("initialclass:" + alternation);
        }

        return root._dispatchFirst(selectors);
    }
}
