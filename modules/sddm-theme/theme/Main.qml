import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#000000"

    // Design tokens. SDDM runs outside Quickshell so values are inlined here.
    // Black background, frosted-white pill, white text/icons.

    readonly property color pillBg: Qt.rgba(1, 1, 1, 0.06)
    readonly property color pillBorder: Qt.rgba(1, 1, 1, 0.2)
    readonly property color pillBorderFocus: Qt.rgba(1, 1, 1, 0.5)
    readonly property color textWhite: "#ffffff"
    readonly property color textDark: "#ffffff"
    readonly property color textMuted: Qt.rgba(1, 1, 1, 0.5)
    readonly property color iconColor: "#ffffff"
    readonly property color hoverHovered: Qt.rgba(1, 1, 1, 0.08)
    readonly property color hoverPressed: Qt.rgba(1, 1, 1, 0.15)
    readonly property color textError: "#ff5e5e"
    readonly property color clockHandColor: "#ffffff"

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

    // webOS-inspired analog clock — bottom-half arc with hour, minute, second hands.
    Item {
        id: clockColumn
        anchors.centerIn: parent
        width: 320
        height: 360

        readonly property int clockSize: 280

        Item {
            id: clockFace
            width: parent.clockSize
            height: parent.clockSize
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top

            readonly property real cx: width / 2
            readonly property real cy: height / 2

            // Bottom semicircle arc (the "smile") — continuously sweeps once per minute.
            Item {
                id: arcRotor
                anchors.fill: parent
                transformOrigin: Item.Center

                NumberAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 4000
                    loops: Animation.Infinite
                    running: true
                }

                Canvas {
                    id: arcCanvas
                    anchors.fill: parent
                    antialiasing: true
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.lineWidth = 3;
                        ctx.strokeStyle = root.clockHandColor;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        var sweep = Math.PI * 2 * 0.4;
                        var start = (Math.PI - sweep) / 2;
                        ctx.arc(clockFace.cx, clockFace.cy, clockFace.width / 2 - 4, start, start + sweep, false);
                        ctx.stroke();
                    }
                }
            }

            // Hour hand
            Rectangle {
                width: 4
                height: 70
                radius: 2
                color: root.clockHandColor
                x: clockFace.cx - width / 2
                y: clockFace.cy - height
                transformOrigin: Item.Bottom
                rotation: (timeModel.time.getHours() % 12) * 30 + timeModel.time.getMinutes() * 0.5
            }

            // Minute hand
            Rectangle {
                width: 3
                height: 105
                radius: 1.5
                color: root.clockHandColor
                x: clockFace.cx - width / 2
                y: clockFace.cy - height
                transformOrigin: Item.Bottom
                rotation: timeModel.time.getMinutes() * 6 + timeModel.time.getSeconds() * 0.1
            }

            // Second hand
            Rectangle {
                width: 1.5
                height: 115
                color: root.clockHandColor
                x: clockFace.cx - width / 2
                y: clockFace.cy - height
                transformOrigin: Item.Bottom
                rotation: timeModel.time.getSeconds() * 6
            }

            // Center cap
            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: root.clockHandColor
                x: clockFace.cx - width / 2
                y: clockFace.cy - height / 2
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clockFace.bottom
            anchors.topMargin: 28
            text: root.germanDate(timeModel.time)
            font.pixelSize: 22
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
            font.pixelSize: 15
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
            TintedIcon {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                source: "icons/icons8-lock-2.svg"
                size: 24
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

                TintedIcon {
                    anchors.centerIn: parent
                    source: "icons/icons8-face-id.svg"
                    size: 28
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

                TintedIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "icons/icons8-spinner.svg"
                    size: 24
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
}
