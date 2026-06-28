import QtQuick
import "."

// Shared visual face for the login/lock screen: solid background-agnostic
// content with a webOS-style analog clock, German date, and a centered password
// pill with an overflowing face-unlock button. Used by both the SDDM login theme
// (modules/sddm-theme/theme/Main.qml) and the Quickshell session lock
// (LockSurface.qml). It carries no authentication logic; the host wires the
// displayed state in through properties and reacts to the signals below.
Item {
    id: panel

    // Pill geometry, shared by the field, the face button, and the error slot.
    readonly property int inputWidth: 280
    readonly property int inputHeight: 48
    readonly property int faceButtonSize: inputHeight

    // Scale applied to the laid-out content. The SDDM theme renders at the
    // compositor's native scale and leaves this at 1; the lock compensates for
    // Hyprland's output scale so both render at the same physical size (see
    // LockSurface.qml).
    property real contentScale: 1

    // Displayed state, driven by the host's auth backend.
    property string userName: ""
    property bool loading: false
    property string loadingMessage: ""
    property string failureMessage: ""
    property bool failureVisible: false

    // Password buffer owned by the host (a shared singleton, so every per-screen
    // instance shows the same text). The panel mirrors changes into its field and
    // emits passwordEdited when the user types; it never writes passwordText.
    property string passwordText: ""
    property bool syncingText: false

    signal passwordEdited(string text)
    signal passwordSubmitted
    signal faceRequested
    signal passkeyRequested

    function focusPassword() {
        passwordField.forceActiveFocus();
    }

    readonly property var dayNames: ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"]
    readonly property var monthNames: ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]

    function germanDate(d) {
        return dayNames[d.getDay()] + ", " + d.getDate() + ". " + monthNames[d.getMonth()];
    }

    // Keep the field in sync with the external buffer (e.g. another screen's
    // edits), preserving the cursor where possible.
    onPasswordTextChanged: {
        if (passwordField.text === passwordText)
            return;
        var keepAtEnd = passwordField.cursorPosition === passwordField.text.length;
        var cursorPosition = passwordField.cursorPosition;
        syncingText = true;
        passwordField.text = passwordText;
        syncingText = false;
        passwordField.cursorPosition = keepAtEnd ? passwordField.text.length : Math.min(cursorPosition, passwordField.text.length);
    }

    Timer {
        id: clockTicker
        property date time: new Date()
        interval: 1000
        running: true
        repeat: true
        onTriggered: time = new Date()
    }

    // Scaled layout container. Scaled by contentScale from the top-left and sized
    // to fill / contentScale, it still covers the full surface, but its children
    // render at contentScale of their design size.
    Item {
        id: contentRoot
        width: panel.width / panel.contentScale
        height: panel.height / panel.contentScale
        scale: panel.contentScale
        transformOrigin: Item.TopLeft

        // webOS-inspired analog clock: bottom-half arc with hour, minute, second hands.
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
                text: panel.germanDate(clockTicker.time)
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
                text: panel.userName
                font.pixelSize: Typography.fontSize16
                font.weight: Font.DemiBold
            }

            // Password pill. Centered on screen via its own width; the face button
            // overflows outside on the right and does not affect centering.
            Rectangle {
                id: passwordPill
                anchors.horizontalCenter: parent.horizontalCenter
                width: panel.inputWidth
                height: panel.inputHeight
                radius: height / 2
                color: panel.loading ? Colors.pillBackgroundLoading : Colors.pillBackground
                border.width: 1
                border.color: panel.loading || passwordField.activeFocus ? Colors.pillBorderFocus : Colors.pillBorder

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
                    inputMethodHints: Qt.ImhSensitiveData
                    focus: true
                    clip: true
                    enabled: !panel.loading
                    opacity: panel.loading ? 0 : 1
                    FadeBehavior on opacity {}

                    onAccepted: panel.passwordSubmitted()

                    onTextChanged: {
                        if (panel.syncingText)
                            return;
                        panel.passwordEdited(text);
                    }
                }

                // Placeholder.
                Label {
                    anchors.fill: passwordField
                    verticalAlignment: Text.AlignVCenter
                    text: "Passwort"
                    font.weight: Font.Normal
                    color: Colors.textColorMuted
                    visible: passwordField.text.length === 0 && !passwordField.activeFocus && !panel.loading
                }

                // Loading overlay: replaces the input content while authenticating.
                Row {
                    anchors.left: lockIcon.right
                    anchors.leftMargin: Spacing.spacing8
                    anchors.right: parent.right
                    anchors.rightMargin: Spacing.spacing16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Spacing.spacing8
                    opacity: panel.loading ? 1 : 0
                    visible: opacity > 0
                    FadeBehavior on opacity {}

                    Label {
                        text: panel.loadingMessage
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
                    visible: panel.loading
                }

                // Face unlock button, anchored to the pill's right edge and overflowing
                // outside so the pill stays centered on screen.
                Rectangle {
                    id: faceButton
                    anchors.left: parent.right
                    anchors.leftMargin: Spacing.spacing8
                    anchors.verticalCenter: parent.verticalCenter
                    width: panel.faceButtonSize
                    height: panel.faceButtonSize
                    radius: height / 2
                    opacity: panel.loading ? 0.4 : 1.0
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
                        cursorShape: panel.loading ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                        enabled: !panel.loading
                        onClicked: panel.faceRequested()
                    }
                }

                // Passkey (FIDO2 security key) button, mirrored on the pill's left
                // edge and overflowing outside so the pill stays centered. Triggers
                // a key-only authentication, separate from the face button.
                Rectangle {
                    id: passkeyButton
                    anchors.right: parent.left
                    anchors.rightMargin: Spacing.spacing8
                    anchors.verticalCenter: parent.verticalCenter
                    width: panel.faceButtonSize
                    height: panel.faceButtonSize
                    radius: height / 2
                    opacity: panel.loading ? 0.4 : 1.0
                    FadeBehavior on opacity {}

                    color: passkeyArea.pressed ? Colors.hoverItemPressed : passkeyArea.containsMouse ? Colors.hoverItemHovered : Colors.pillBackground
                    border.width: 1
                    border.color: passkeyArea.containsMouse ? Colors.pillBorderFocus : Colors.pillBorder

                    scale: passkeyArea.pressed ? 0.85 : 1.0
                    SquishBehavior on scale {}

                    TintedIcon {
                        anchors.centerIn: parent
                        source: "icons/icons8-passkey.svg"
                        size: Typography.fontSize24 + Spacing.spacing4
                        color: Colors.textColor
                    }

                    MouseArea {
                        id: passkeyArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: panel.loading ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                        enabled: !panel.loading
                        onClicked: panel.passkeyRequested()
                    }
                }
            }

            // Error slot. Fixed height reserves layout space so the pill does not
            // shift when an error appears.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: panel.inputWidth
                height: Typography.fontSize24

                Label {
                    anchors.centerIn: parent
                    text: panel.failureMessage
                    visible: !panel.loading && panel.failureVisible && panel.failureMessage !== ""
                    font.pixelSize: Typography.fontSize16
                    font.weight: Font.Normal
                    color: Colors.textError
                }
            }
        }
    }
}
