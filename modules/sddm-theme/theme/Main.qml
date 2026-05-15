import QtQuick 2.0
import SddmComponents 2.0
import "."

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: Colors.background

    readonly property int inputWidth: 280
    readonly property int inputHeight: 48
    readonly property int faceButtonSize: inputHeight
    readonly property int errorAutoHideMs: 3000

    property int currentUserIndex: userModel.lastIndex
    readonly property string instanceId: "screen-" + Math.floor(Math.random() * 1000000000)
    readonly property bool isLoading: Globals.authLoading
    readonly property string loadingMessage: Globals.authAttemptKind === "face" ? "Gesicht wird erkannt…" : "Wird überprüft…"
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
        id: clockTicker
        property date time: new Date()
        interval: 1000
        running: true
        repeat: true
        onTriggered: time = new Date()
    }

    Timer {
        id: errorTimer
        interval: root.errorAutoHideMs
        onTriggered: Globals.authErrorVisible = false
    }

    // webOS-inspired analog clock — bottom-half arc with hour, minute, second hands.
    Item {
        id: clockColumn
        anchors.centerIn: parent
        width: 320
        height: 360

        readonly property int clockSize: 280
        readonly property int hourHandWidth: 4
        readonly property int hourHandHeight: 70
        readonly property int minuteHandWidth: 3
        readonly property int minuteHandHeight: 105
        readonly property real secondHandWidth: 1.5
        readonly property int secondHandHeight: 115
        readonly property int centerCapSize: 8

        Item {
            id: clockFace
            width: parent.clockSize
            height: parent.clockSize
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top

            readonly property real cx: width / 2
            readonly property real cy: height / 2

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
                    anchors.fill: parent
                    antialiasing: true
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.lineWidth = 3;
                        ctx.strokeStyle = Colors.textColor;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        var sweep = Math.PI * 2 * 0.4;
                        var start = (Math.PI - sweep) / 2;
                        ctx.arc(clockFace.cx, clockFace.cy, clockFace.width / 2 - 4, start, start + sweep, false);
                        ctx.stroke();
                    }
                }
            }

            Rectangle {
                width: clockColumn.hourHandWidth
                height: clockColumn.hourHandHeight
                radius: width / 2
                color: Colors.textColor
                x: clockFace.cx - width / 2
                y: clockFace.cy - height
                transformOrigin: Item.Bottom
                rotation: (clockTicker.time.getHours() % 12) * 30 + clockTicker.time.getMinutes() * 0.5
            }

            Rectangle {
                width: clockColumn.minuteHandWidth
                height: clockColumn.minuteHandHeight
                radius: width / 2
                color: Colors.textColor
                x: clockFace.cx - width / 2
                y: clockFace.cy - height
                transformOrigin: Item.Bottom
                rotation: clockTicker.time.getMinutes() * 6 + clockTicker.time.getSeconds() * 0.1
            }

            Rectangle {
                width: clockColumn.secondHandWidth
                height: clockColumn.secondHandHeight
                color: Colors.textColor
                x: clockFace.cx - width / 2
                y: clockFace.cy - height
                transformOrigin: Item.Bottom
                rotation: clockTicker.time.getSeconds() * 6
            }

            Rectangle {
                width: clockColumn.centerCapSize
                height: width
                radius: width / 2
                color: Colors.textColor
                x: clockFace.cx - width / 2
                y: clockFace.cy - height / 2
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clockFace.bottom
            anchors.topMargin: Spacing.spacing24 + Spacing.spacing4
            text: root.germanDate(clockTicker.time)
            font.pixelSize: Typography.fontSize20
            font.weight: Font.DemiBold
        }
    }

    Column {
        id: inputColumn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Spacing.spacing40 * 2
        spacing: Spacing.spacing12

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.userName()
            font.pixelSize: Typography.fontSize16
            font.weight: Font.DemiBold
        }

        // Password pill. Centered on screen via its own width — face button overflows
        // outside on the right and does not affect centering.
        Rectangle {
            id: passwordPill
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.inputWidth
            height: root.inputHeight
            radius: height / 2
            color: root.isLoading ? Colors.pillBackgroundLoading : Colors.pillBackground
            border.width: 1
            border.color: root.isLoading || passwordField.activeFocus ? Colors.pillBorderFocus : Colors.pillBorder

            TintedIcon {
                id: lockIcon
                anchors.left: parent.left
                anchors.leftMargin: Spacing.spacing16 + Spacing.spacing2
                anchors.verticalCenter: parent.verticalCenter
                source: "icons/icons8-password-key.svg"
                size: Typography.fontSize24
                color: Colors.textColor
            }

            TextInput {
                id: passwordField
                anchors.left: lockIcon.right
                anchors.leftMargin: Spacing.spacing8
                anchors.right: parent.right
                anchors.rightMargin: Spacing.spacing16 + Spacing.spacing4
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: Typography.fontSize14
                font.family: Typography.fontFamily
                color: Colors.textColor
                echoMode: TextInput.Password
                focus: true
                clip: true
                enabled: !root.isLoading
                opacity: root.isLoading ? 0 : 1
                FadeBehavior on opacity {}

                onAccepted: root.submitAuth("password", text)

                onTextChanged: {
                    if (root.syncingPasswordFromGlobals)
                        return;
                    Globals.authInputOwner = root.instanceId;
                    Globals.authPassword = text;
                    root.clearError();
                }
            }

            // Placeholder.
            Label {
                anchors.fill: passwordField
                verticalAlignment: Text.AlignVCenter
                text: "Passwort"
                font.weight: Font.Normal
                color: Colors.textColorMuted
                visible: passwordField.text.length === 0 && !passwordField.activeFocus && !root.isLoading
            }

            // Loading overlay — replaces the input content while authenticating.
            Row {
                anchors.left: lockIcon.right
                anchors.leftMargin: Spacing.spacing8
                anchors.right: parent.right
                anchors.rightMargin: Spacing.spacing16
                anchors.verticalCenter: parent.verticalCenter
                spacing: Spacing.spacing8
                opacity: root.isLoading ? 1 : 0
                visible: opacity > 0
                FadeBehavior on opacity {}

                Label {
                    text: root.loadingMessage
                    font.weight: Font.Normal
                    color: Colors.textColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Spinner {
                anchors.right: parent.right
                anchors.rightMargin: Spacing.spacing16
                anchors.verticalCenter: parent.verticalCenter
                size: Typography.fontSize20
                visible: root.isLoading
            }

            // Face unlock button — anchored to the pill's right edge, overflowing
            // outside so the pill itself stays centered on screen.
            Rectangle {
                id: faceButton
                anchors.left: parent.right
                anchors.leftMargin: Spacing.spacing8
                anchors.verticalCenter: parent.verticalCenter
                width: root.faceButtonSize
                height: root.faceButtonSize
                radius: height / 2
                opacity: root.isLoading ? 0.4 : 1.0
                FadeBehavior on opacity {}

                color: faceArea.pressed ? Colors.hoverItemPressed : faceArea.containsMouse ? Colors.hoverItemHovered : Colors.pillBackground
                border.width: 1
                border.color: faceArea.containsMouse ? Colors.pillBorderFocus : Colors.pillBorder

                scale: faceArea.pressed ? 0.85 : 1.0
                SquishBehavior on scale {}

                TintedIcon {
                    anchors.centerIn: parent
                    source: "icons/icons8-face-id.svg"
                    size: Typography.fontSize24 + Spacing.spacing4
                    color: Colors.textColor
                }

                MouseArea {
                    id: faceArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.isLoading ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                    enabled: !root.isLoading
                    onClicked: root.submitAuth("face", "")
                }
            }
        }

        // Error message slot — fixed height reserves layout space so the
        // pill doesn't shift when an error appears.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.inputWidth
            height: Typography.fontSize24

            Label {
                anchors.centerIn: parent
                text: Globals.authErrorMessage
                visible: !root.isLoading && Globals.authErrorVisible && Globals.authErrorMessage !== ""
                font.pixelSize: Typography.fontSize16
                font.weight: Font.Normal
                color: Colors.textError
            }
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
            passwordField.forceActiveFocus();
        }
        function onLoginSucceeded() {
            // Keep loading true until the session starts so the user can't click again.
            root.clearError();
            Globals.authAttemptKind = "";
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
            passwordField.cursorPosition = keepAtEnd ? passwordField.text.length : Math.min(cursorPosition, passwordField.text.length);
        }
    }

    Component.onCompleted: {
        if (Globals.authInputOwner === "")
            Globals.authInputOwner = root.instanceId;
        passwordField.text = Globals.authPassword;
        passwordField.forceActiveFocus();
    }
}
