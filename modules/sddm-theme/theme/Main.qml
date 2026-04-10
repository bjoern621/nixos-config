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
    readonly property color pillBorder: Qt.rgba(0, 0, 0, 0.2)
    readonly property color pillBorderFocus: Qt.rgba(0, 0, 0, 0.4)
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

    property int currentUserIndex: userModel.lastIndex
    property bool manualAttempt: false
    property bool faceAuthActive: false
    property bool isLoading: false
    property bool errorVisible: false
    property string errorMessageText: ""
    readonly property bool autoSilentLogin: config.autoSilentLogin === "true"

    readonly property var dayNames: ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"]
    readonly property var monthNames: ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]

    function userName() {
        return userModel.data(userModel.index(currentUserIndex, 0), Qt.UserRole + 1) || "Unbekannter Benutzer";
    }

    function germanDate(d) {
        return dayNames[d.getDay()] + ", " + d.getDate() + ". " + monthNames[d.getMonth()];
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
            border.color: root.isLoading ? Qt.rgba(0, 0, 0, 0.1) : (passwordField.activeFocus ? root.pillBorderFocus : root.pillBorder)
            opacity: root.isLoading ? 0.6 : 1.0

            // Lock icon
            Image {
                id: lockIconSource
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                source: "icons/icons8-lock.svg"
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

                transformOrigin: Item.Left
                scale: 1.0
                SquishBehavior on scale {
                    enabled: !root.isLoading
                    duration: 120
                    bouncy: true
                }

                onAccepted: {
                    if (text.length === 0 || root.isLoading)
                        return;
                    root.isLoading = true;
                    autoLoginTimer.stop();
                    root.manualAttempt = true;
                    root.errorVisible = false;
                    sddm.login(root.userName(), text, sessionModel.lastIndex);
                }

                onTextChanged: {
                    if (root.isLoading)
                        return;
                    scale = 0.95;
                    scaleTimer.restart();
                    if (root.autoSilentLogin && text.length > 0) {
                        autoLoginTimer.restart();
                    } else {
                        autoLoginTimer.stop();
                    }
                }

                Timer {
                    id: scaleTimer
                    interval: 20
                    onTriggered: passwordField.scale = 1.0
                }
            }

            Timer {
                id: autoLoginTimer
                interval: 500
                onTriggered: {
                    if (passwordField.text.length > 0 && !root.isLoading) {
                        root.manualAttempt = false;
                        root.errorVisible = false;
                        sddm.login(root.userName(), passwordField.text, sessionModel.lastIndex);
                    }
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
                border.color: root.isLoading ? Qt.rgba(0, 0, 0, 0.1) : (faceArea.containsMouse ? root.pillBorderFocus : root.pillBorder)
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
                    cursorShape: root.isLoading ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !root.isLoading
                    onClicked: {
                        if (root.isLoading)
                            return;
                        root.isLoading = true;
                        autoLoginTimer.stop();
                        passwordField.text = "";
                        root.faceAuthActive = true;
                        root.manualAttempt = true;
                        root.errorVisible = false;
                        sddm.login(root.userName(), "", sessionModel.lastIndex);
                    }
                }
            }
        }

        // Error message or loading indication
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.inputWidth
            height: 24

            ContentReplace {
                id: statusReplace
                anchors.centerIn: parent
                contentKey: root.isLoading ? "loading" : (root.errorVisible ? root.errorMessageText : "")

                Item {
                    anchors.centerIn: parent
                    width: Math.max(errorMessage.width, loadingRow.width)
                    height: 24

                    Label {
                        id: errorMessage
                        anchors.centerIn: parent
                        text: statusReplace.displayValue !== "loading" ? statusReplace.displayValue : ""
                        visible: statusReplace.displayValue !== "loading" && statusReplace.displayValue !== ""
                        font.pixelSize: Typography.fontSize18
                        color: root.textError
                    }

                    Row {
                        id: loadingRow
                        anchors.centerIn: parent
                        spacing: 12
                        visible: statusReplace.displayValue === "loading"

                        Label {
                            text: "Bitte warten..."
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
                                running: root.isLoading || statusReplace.displayValue === "loading"
                            }
                        }
                    }
                }
            }

            Timer {
                id: errorTimer
                interval: 3000
                onTriggered: root.errorVisible = false
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
            root.isLoading = false;
            // Delay clear active focus out of the disabled state
            if (root.faceAuthActive) {
                root.errorMessageText = "Gesicht nicht erkannt";
                root.faceAuthActive = false;
            } else if (root.manualAttempt) {
                root.errorMessageText = "Falsches Passwort";
            }
            root.errorVisible = true;
            errorTimer.restart();
            passwordField.forceActiveFocus();
        }
        function onLoginSucceeded() {
            // Keep loading true till the session starts to prevent user clicking
            root.errorVisible = false;
            root.faceAuthActive = false;
        }
    }

    Component.onCompleted: {
        passwordField.forceActiveFocus();
    }

    ScreenCorners {}
}
