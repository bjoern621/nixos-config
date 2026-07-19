pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Hyprland._GlobalShortcuts
import Quickshell.Io
import QtQuick
import "../"
import "../lib/fzf.js" as FzfLib

// Shared app-launcher behavior, preferring the neo launcher's logic.
// Both launcher views (classic AppLauncher, neo AppLauncherNeo) bind to this;
// the view holds only layout + rendering. Singleton so the GlobalShortcut and
// IpcHandler have exactly one owner regardless of which view is loaded.
// resultCount + activeIndex are exposed for the neo readout; classic ignores them.
Singleton {
    id: controller

    readonly property int maxResults: 50
    // Per-field weights: name dominates, comment is tiebreaker.
    readonly property var fieldWeights: [3.0, 1.5, 1.2, 0.7]

    readonly property bool launcherVisible: Globals.launcherVisible
    property string searchText: ""
    property var indexedApps: []
    property var filteredApps: []
    property int activeIndex: 0
    // Keyboard nav briefly suppresses hover-select so a list scrolling under a
    // stationary cursor does not steal the selection.
    property bool kbdLock: false

    // Neo readout data. Classic does not display these.
    readonly property int resultCount: filteredApps.length

    readonly property var selectedApp: (filteredApps.length > 0 && activeIndex >= 0 && activeIndex < filteredApps.length) ? filteredApps[activeIndex].app : null

    onLauncherVisibleChanged: {
        if (launcherVisible) {
            searchText = "";
            updateFilter();
        }
    }

    onSearchTextChanged: updateFilter()

    function rebuildAppList() {
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name));
        indexedApps = apps.map(app => {
            const kw = app.keywords;
            const keywords = kw && kw.length ? Array.prototype.join.call(kw, " ") : "";
            const fields = [app.name || "", app.genericName || "", keywords, app.comment || ""];
            return {
                app,
                fields,
                lower: fields.map(f => f.toLowerCase())
            };
        });
    }

    function updateFilter() {
        const query = searchText.toLowerCase();
        if (query === "") {
            filteredApps = indexedApps.slice(0, maxResults).map(e => ({
                        app: e.app,
                        query: ""
                    }));
            activeIndex = 0;
            return;
        }

        const weights = fieldWeights;
        const scored = [];
        for (let i = 0; i < indexedApps.length; i++) {
            const e = indexedApps[i];
            let best = -Infinity;
            for (let f = 0; f < e.fields.length; f++) {
                const raw = FzfLib.scoreLower(e.fields[f], e.lower[f], query);
                if (raw === -Infinity)
                    continue;
                const weighted = raw * weights[f];
                if (weighted > best)
                    best = weighted;
            }
            if (best > -Infinity)
                scored.push({
                    app: e.app,
                    score: best
                });
        }
        scored.sort((a, b) => b.score - a.score || a.app.name.localeCompare(b.app.name));

        const limit = Math.min(scored.length, maxResults);
        const out = new Array(limit);
        for (let i = 0; i < limit; i++)
            out[i] = {
                app: scored[i].app,
                query: query
            };
        filteredApps = out;
        activeIndex = 0;
    }

    // View watches activeIndex to scroll its own list into view.
    function move(delta) {
        const n = filteredApps.length;
        if (n === 0)
            return;
        activeIndex = Math.max(0, Math.min(activeIndex + delta, n - 1));
        kbdLock = true;
        kbdTimer.restart();
    }

    function launchSelected() {
        if (selectedApp)
            launchApp(selectedApp);
    }

    function launchApp(app) {
        Globals.launcherVisible = false;
        Quickshell.execDetached(["uwsm", "app", "--", app.id + ".desktop"]);
    }

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor;
        return mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? null) : null;
    }

    function toggle() {
        if (!launcherVisible) {
            const s = focusedScreen();
            if (s)
                Globals.launcherScreenName = s.name;
        }
        Globals.launcherVisible = !launcherVisible;
    }

    property Timer kbdTimer: Timer {
        interval: 250
        onTriggered: controller.kbdLock = false
    }

    property Connections _deConn: Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            controller.rebuildAppList();
            controller.updateFilter();
        }
    }

    // Hyprland delivers SUPER tap directly to this process via the wlr
    // global-shortcuts protocol. Single owner, so no duplicate-handler warning.
    property GlobalShortcut _shortcut: GlobalShortcut {
        appid: "quickshell"
        name: "launcher"
        description: "Toggle the app launcher"
        onPressed: controller.toggle()
    }

    property IpcHandler _ipc: IpcHandler {
        target: "launcher"
        function toggle(): void {
            controller.toggle();
        }
    }

    Component.onCompleted: rebuildAppList()
}
