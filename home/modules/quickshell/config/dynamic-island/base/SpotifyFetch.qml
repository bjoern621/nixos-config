import QtQuick
import Quickshell
import Quickshell.Io

// One spotify_api.py subcommand as a rate-limited fetch.
// request() starts it at most once per cooldown.
// A request landing inside the cooldown or during a run folds into one
// follow-up, so next-spam or a hover burst costs one extra fetch at most
// and the newest state still lands.
// Every start reaches an exit, SIGTERM at worst, and every exit clears loading.
Scope {
    id: root

    required property string subcommand
    required property string scriptPath
    // ms between two starts. Bounds how long optimistic state drifts from Spotify.
    property int cooldown: 5000
    // One JSON object per run, as the subcommand printed it.
    signal payload(var result)

    property bool loading: false
    property bool _pending: false

    function request() {
        if (cooldownTimer.running || root.loading) {
            root._pending = true;
            return;
        }
        root._start();
    }

    // Deferred request runs once cooldown and fetch are both idle.
    // Cooldown expiry and process exit both land here,
    // so whichever comes last starts it.
    function _flush() {
        if (!root._pending || cooldownTimer.running || root.loading)
            return;
        root._pending = false;
        root._start();
    }

    function _start() {
        root.loading = true;
        process.command = ["python3", root.scriptPath, root.subcommand];
        process.running = true;
        watchdog.restart();
        cooldownTimer.restart();
    }

    Process {
        id: process

        stdout: SplitParser {
            onRead: data => {
                try {
                    root.payload(JSON.parse(data));
                } catch (e) {
                    // Non-JSON line. Next fetch reconciles.
                }
            }
        }

        // Swallows keyring and API errors. Without a parser they reach the shell log.
        stderr: SplitParser {
            onRead: data => {}
        }

        onExited: {
            watchdog.stop();
            // Unconditional: exit 0 without parseable output would latch the flag
            // and kill every later fetch for the session.
            root.loading = false;
            exitFlush.restart();
        }
    }

    // keyring calls in spotify_api.py have no timeout; a locked keyring blocks forever.
    // SIGTERM lands in onExited, which does the bookkeeping.
    Timer {
        id: watchdog
        interval: 30000
        onTriggered: process.signal(15)
    }

    Timer {
        id: cooldownTimer
        interval: root.cooldown
        onTriggered: root._flush()
    }

    // Starting a fetch straight from onExited would hit a Process that has not
    // cleared running yet, and assigning command/running on a running Process is a no-op.
    Timer {
        id: exitFlush
        interval: 0
        onTriggered: root._flush()
    }
}
