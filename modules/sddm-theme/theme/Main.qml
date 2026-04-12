import QtQuick 2.0
import Qt5Compat.GraphicalEffects
import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#1a1a2e"

    // Design tokens mirroring the Quickshell singletons (Colors, Typography, Spacing).
    // SDDM runs outside Quickshell so those singletons are unavailable here — values
    // are inlined manually and should stay in sync with their Quickshell counterparts.

    readonly property color pillBg: Qt.rgba(1, 1, 1, 0.5)
    readonly property color pillBorder: Qt.rgba(1, 1, 1, 0.2)
    readonly property color pillBorderFocus: Qt.rgba(1, 1, 1, 0.35)
    readonly property color textWhite: "#ffffff"
    readonly property color textDark: "#111111"
    readonly property color textMuted: "#555555"
    readonly property color iconColor: "#111111"
    readonly property color hoverHovered: Qt.rgba(0, 0, 0, 0.08)
    readonly property color hoverPressed: Qt.rgba(0, 0, 0, 0.15)
    readonly property color textError: "#ff3b3b"

    readonly property int inputWidth: 280
    readonly property int inputHeight: 48
    readonly property int faceButtonSize: inputHeight
    property int autoLoginIntervalMs: 500

    property int currentUserIndex: userModel.lastIndex
    readonly property string instanceId: "screen-" + Math.floor(Math.random() * 1000000000)
    readonly property bool isLoading: Globals.authLoading
    readonly property bool errorVisible: Globals.authErrorVisible
    readonly property string errorMessageText: Globals.authErrorMessage
    readonly property bool autoSilentLogin: config.autoSilentLogin === "true"
    readonly property string loadingMessage: Globals.authAttemptKind === "face" ? "Gesicht wird erkannt..." : "Bitte warten..."
    property bool syncingPasswordFromGlobals: false

    readonly property var dayNames: ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"]
    readonly property var monthNames: ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]

    function userName() {
        return userModel.data(userModel.index(currentUserIndex, 0), Qt.UserRole + 1) || "Unbekannter Benutzer";
    }

    function germanDate(d) {
        return dayNames[d.getDay()] + ", " + d.getDate() + ". " + monthNames[d.getMonth()];
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

    function scheduleAutoSubmit() {
        autoLoginTimer.stop();
        if (!root.autoSilentLogin || Globals.authLoading)
            return;
        if (Globals.authInputOwner !== root.instanceId) {
            if (passwordField.activeFocus) {
                Globals.authInputOwner = root.instanceId;
            } else {
                return;
            }
        }
        if (Globals.authPassword.length === 0)
            return;
        autoLoginTimer.restart();
    }

    function submitAuth(kind, password) {
        if (Globals.authLoading)
            return false;
        if (kind !== "face" && (!password || password.length === 0))
            return false;

        autoLoginTimer.stop();
        Globals.authInputOwner = root.instanceId;
        Globals.authLoading = true;
        Globals.authAttemptKind = kind;
        Globals.authQueuedAttemptKind = "";
        Globals.authQueuedPassword = "";
        root.clearError();

        sddm.login(root.userName(), kind === "face" ? "" : password, sessionModel.lastIndex);
        return true;
    }

    function queueFaceAuth() {
        autoLoginTimer.stop();
        Globals.authInputOwner = root.instanceId;

        if (!Globals.authLoading) {
            Globals.authPassword = "";
            root.submitAuth("face", "");
            return;
        }

        if (Globals.authAttemptKind === "auto") {
            Globals.authQueuedAttemptKind = "face";
            Globals.authQueuedPassword = "";
        }
    }

    // Background wallpaper
    Image {
        id: wallpaper
        anchors.fill: parent
        source: config.background || ""
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    // Full-screen blurred background
    FastBlur {
        anchors.fill: parent
        source: wallpaper
        radius: 64
        visible: wallpaper.status === Image.Ready
    }

    // Clock + date — centered on screen
    Column {
        id: clockColumn
        anchors.centerIn: parent
        spacing: 4

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(timeModel.time, "HH:mm")
            font.pixelSize: 120
            color: root.textWhite
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.germanDate(timeModel.time)
            font.pixelSize: Typography.fontSize24
            font.weight: Font.DemiBold
            color: root.textWhite
        }
    }

    // Input area — anchored to bottom of screen
    Column {
        id: inputColumn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80
        spacing: 12

        // Username label
        Label {
            id: usernameLabel
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.userName()
            font.weight: Font.DemiBold
            color: root.textWhite
        }

        // Password pill — centered by the Column, full inputWidth
        Rectangle {
            id: passwordPill
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.inputWidth
            height: root.inputHeight
            radius: height / 2
            color: root.isLoading ? Qt.rgba(0.9, 0.9, 0.9, 0.3) : root.pillBg
            border.width: 1
            border.color: root.isLoading ? Qt.rgba(1, 1, 1, 0.18) : (passwordField.activeFocus ? root.pillBorderFocus : root.pillBorder)
            opacity: root.isLoading ? 0.6 : 1.0

            // Lock icon
            Image {
                id: lockIconSource
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                source: "icons/icons8-lock-2.svg"
                sourceSize: Qt.size(24, 24)
                width: 24
                height: 24
                visible: false
            }
            ColorOverlay {
                anchors.fill: lockIconSource
                source: lockIconSource
                color: root.iconColor
            }

            TextInput {
                id: passwordField
                anchors.fill: parent
                anchors.leftMargin: 50
                anchors.rightMargin: 20
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: Typography.fontSize14
                font.family: Typography.fontFamily
                color: root.textDark
                echoMode: TextInput.Password
                focus: true
                clip: true
                enabled: !root.isLoading

                onAccepted: {
                    root.submitAuth("manual", text);
                }

                onTextChanged: {
                    if (!root.syncingPasswordFromGlobals) {
                        Globals.authInputOwner = root.instanceId;
                        Globals.authPassword = text;
                        root.clearError();
                    }
                    root.scheduleAutoSubmit();
                }
            }

            Timer {
                id: autoLoginTimer
                interval: root.autoLoginIntervalMs
                onTriggered: {
                    root.submitAuth("auto", Globals.authPassword);
                }
            }

            // Placeholder
            Label {
                anchors.fill: parent
                anchors.leftMargin: 50
                anchors.rightMargin: 20
                verticalAlignment: Text.AlignVCenter
                text: "Passwort"
                font.weight: Font.Normal
                color: root.textMuted
                visible: passwordField.text.length === 0 && !passwordField.activeFocus
            }

            // Face unlock button
            Rectangle {
                id: faceButton
                anchors.left: parent.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: root.faceButtonSize
                height: root.faceButtonSize
                radius: height / 2
                color: root.isLoading ? Qt.rgba(0.9, 0.9, 0.9, 0.3) : (faceArea.pressed && !root.isLoading ? Qt.tint(root.pillBg, root.hoverPressed) : (faceArea.containsMouse && !root.isLoading ? Qt.tint(root.pillBg, root.hoverHovered) : root.pillBg))
                border.width: 1
                border.color: root.isLoading ? Qt.rgba(1, 1, 1, 0.18) : (faceArea.containsMouse ? root.pillBorderFocus : root.pillBorder)
                opacity: root.isLoading ? 0.6 : 1.0

                scale: faceArea.pressed && !root.isLoading ? 0.85 : 1.0
                SquishBehavior on scale {
                    enabled: !root.isLoading
                    duration: 100
                }

                Image {
                    id: faceIconSource
                    anchors.centerIn: parent
                    source: "icons/icons8-face-id.svg"
                    sourceSize: Qt.size(28, 28)
                    width: 28
                    height: 28
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: faceIconSource
                    source: faceIconSource
                    color: root.iconColor
                }

                MouseArea {
                    id: faceArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: true
                    onClicked: {
                        root.queueFaceAuth();
                    }
                }
            }
        }

        // Error message or loading indication
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.inputWidth
            height: 24

            Label {
                id: errorMessage
                anchors.centerIn: parent
                text: root.errorMessageText
                visible: !root.isLoading && root.errorVisible && root.errorMessageText !== ""
                font.pixelSize: Typography.fontSize18
                color: root.textError
            }

            Row {
                id: loadingRow
                anchors.centerIn: parent
                spacing: 12
                visible: root.isLoading

                Label {
                    text: root.loadingMessage
                    font.pixelSize: Typography.fontSize18
                    color: root.textWhite
                    anchors.verticalCenter: parent.verticalCenter
                }

                Image {
                    id: spinnerIconSource
                    source: "icons/icons8-spinner.svg"
                    sourceSize: Qt.size(24, 24)
                    width: 24
                    height: 24
                    visible: false
                }
                ColorOverlay {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    source: spinnerIconSource
                    color: root.textWhite

                    NumberAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                        running: root.isLoading
                    }
                }
            }

            Timer {
                id: errorTimer
                interval: 3000
                onTriggered: Globals.authErrorVisible = false
            }
        }
    }

    // Time model
    Timer {
        id: timeModel
        property date time: new Date()
        interval: 1000
        running: true
        repeat: true
        onTriggered: time = new Date()
    }

    // Handle login events
    Connections {
        target: sddm
        function onLoginFailed() {
            if (!Globals.authLoading)
                return;

            var failedKind = Globals.authAttemptKind;
            var queuedKind = Globals.authQueuedAttemptKind;
            var queuedPassword = Globals.authQueuedPassword;

            Globals.authLoading = false;
            Globals.authAttemptKind = "";
            Globals.authQueuedAttemptKind = "";
            Globals.authQueuedPassword = "";

            if (queuedKind !== "") {
                if (queuedKind === "face")
                    Globals.authPassword = "";
                root.submitAuth(queuedKind, queuedPassword);
                return;
            }

            if (failedKind === "face") {
                root.showError("Gesicht nicht erkannt");
            } else if (failedKind === "manual") {
                root.showError("Falsches Passwort");
            } else {
                root.showError("Falsches Passwort");
            }

            passwordField.forceActiveFocus();
        }
        function onLoginSucceeded() {
            // Keep loading true till the session starts to prevent user clicking
            root.clearError();
            Globals.authAttemptKind = "";
            Globals.authQueuedAttemptKind = "";
            Globals.authQueuedPassword = "";
        }
    }

    Connections {
        target: Globals
        function onAuthPasswordChanged() {
            if (passwordField.text === Globals.authPassword)
                return;

            var keepAtEnd = passwordField.cursorPosition === passwordField.text.length;
            var cursorPosition = passwordField.cursorPosition;
            root.syncingPasswordFromGlobals = true;
            passwordField.text = Globals.authPassword;
            root.syncingPasswordFromGlobals = false;
            if (keepAtEnd) {
                passwordField.cursorPosition = passwordField.text.length;
            } else {
                passwordField.cursorPosition = Math.min(cursorPosition, passwordField.text.length);
            }
            root.scheduleAutoSubmit();
        }
    }

    Component.onCompleted: {
        if (Globals.authInputOwner === "")
            Globals.authInputOwner = root.instanceId;
        passwordField.text = Globals.authPassword;
        passwordField.forceActiveFocus();
    }

    ScreenCorners {}
}
