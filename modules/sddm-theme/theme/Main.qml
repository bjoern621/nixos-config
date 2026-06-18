import QtQuick
import SddmComponents 2.0
import "."

// SDDM login theme. The visual face is the shared LoginPanel, also used by the
// Quickshell session lock (home/modules/quickshell/config/lock/LockSurface.qml).
// This file only wires the panel to SDDM's auth backend: sddm.login() plus the
// Globals singleton, which keeps password text and status in sync across the
// per-screen instances SDDM spawns.
Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: Colors.background

    readonly property int errorAutoHideMs: 3000

    property int currentUserIndex: userModel.lastIndex
    readonly property string instanceId: "screen-" + Math.floor(Math.random() * 1000000000)
    readonly property bool isLoading: Globals.authLoading
    readonly property string loadingMessage: Globals.authAttemptKind === "face" ? "Gesicht wird erkannt…" : "Wird überprüft…"

    function userName() {
        return userModel.data(userModel.index(currentUserIndex, 0), Qt.UserRole + 1) || "Unbekannter Benutzer";
    }

    function clearError() {
        Globals.authErrorVisible = false;
        Globals.authErrorMessage = "";
        errorTimer.stop();
    }

    function showError(message) {
        Globals.authErrorMessage = message;
        Globals.authErrorVisible = true;
        errorTimer.restart();
    }

    function submitAuth(kind, password) {
        if (Globals.authLoading)
            return;
        if (kind !== "face" && (!password || password.length === 0))
            return;

        Globals.authInputOwner = root.instanceId;
        Globals.authAttemptKind = kind;
        Globals.authLoading = true;
        root.clearError();
        sddm.login(root.userName(), kind === "face" ? "" : password, sessionModel.lastIndex);
    }

    Timer {
        id: errorTimer
        interval: root.errorAutoHideMs
        onTriggered: Globals.authErrorVisible = false
    }

    LoginPanel {
        id: panel
        anchors.fill: parent

        userName: root.userName()
        loading: root.isLoading
        loadingMessage: root.loadingMessage
        failureMessage: Globals.authErrorMessage
        failureVisible: Globals.authErrorVisible
        passwordText: Globals.authPassword

        onPasswordEdited: text => {
            Globals.authInputOwner = root.instanceId;
            Globals.authPassword = text;
            root.clearError();
        }
        onPasswordSubmitted: root.submitAuth("password", Globals.authPassword)
        onFaceRequested: root.submitAuth("face", "")

        Component.onCompleted: {
            if (Globals.authInputOwner === "")
                Globals.authInputOwner = root.instanceId;
            focusPassword();
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            if (!Globals.authLoading)
                return;
            if (Globals.authInputOwner !== root.instanceId)
                return;

            var failedKind = Globals.authAttemptKind;
            Globals.authLoading = false;
            Globals.authAttemptKind = "";

            root.showError(failedKind === "face" ? "Gesicht nicht erkannt" : "Falsches Passwort");
            panel.focusPassword();
        }
        function onLoginSucceeded() {
            // Keep loading true until the session starts so the user can't click again.
            root.clearError();
            Globals.authAttemptKind = "";
        }
    }
}
