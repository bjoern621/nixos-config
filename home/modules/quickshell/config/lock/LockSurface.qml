import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

// Lock surface, rendered once per screen. Visual design is ported from the SDDM
// login theme (modules/sddm-theme/theme/Main.qml): solid background, webOS-style
// analog clock, German date, and a centered password pill with an overflowing
// face-unlock button. Authentication is delegated entirely to the shared
// LockContext, so the login look is reused without reusing the login logic.
Rectangle {
	id: root

	required property LockContext context

	readonly property int inputWidth: 280
	readonly property int inputHeight: 48
	readonly property int faceButtonSize: inputHeight

	readonly property bool isLoading: context.unlockInProgress
	readonly property string loadingMessage: context.attemptKind === "face"
		? "Gesicht wird erkannt…"
		: "Wird überprüft…"
	readonly property string userName: Quickshell.env("USER") || "Benutzer"

	property bool syncingTextFromContext: false

	readonly property var dayNames: ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"]
	readonly property var monthNames: ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]

	color: Colors.background

	function germanDate(d) {
		return dayNames[d.getDay()] + ", " + d.getDate() + ". " + monthNames[d.getMonth()];
	}

	// Put keyboard focus on the password field. forceActiveFocus is scoped to
	// each surface's own window, so the compositor still routes keys to the
	// focused monitor; the shared LockContext keeps every field's text in sync.
	Component.onCompleted: passwordField.forceActiveFocus()

	Timer {
		id: clockTicker
		property date time: new Date()
		interval: 1000
		running: true
		repeat: true
		onTriggered: time = new Date()
	}

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
			text: root.userName
			font.pixelSize: Typography.fontSize16
			font.weight: Font.DemiBold
		}

		// Password pill. Centered on screen via its own width; the face button
		// overflows outside on the right and does not affect centering.
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
				inputMethodHints: Qt.ImhSensitiveData
				focus: true
				clip: true
				enabled: !root.isLoading
				opacity: root.isLoading ? 0 : 1
				FadeBehavior on opacity {}

				onAccepted: root.context.tryPassword()

				onTextChanged: {
					if (root.syncingTextFromContext) return;
					root.context.currentText = text;
				}

				// Keep every monitor's field in sync with the shared buffer.
				Connections {
					target: root.context
					function onCurrentTextChanged() {
						if (passwordField.text === root.context.currentText) return;
						root.syncingTextFromContext = true;
						passwordField.text = root.context.currentText;
						passwordField.cursorPosition = passwordField.text.length;
						root.syncingTextFromContext = false;
					}
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

			// Loading overlay: replaces the input content while authenticating.
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

			// Face unlock button, anchored to the pill's right edge and overflowing
			// outside so the pill stays centered on screen.
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
					onClicked: root.context.tryFace()
				}
			}
		}

		// Error slot. Fixed height reserves layout space so the pill does not
		// shift when an error appears.
		Item {
			anchors.horizontalCenter: parent.horizontalCenter
			width: root.inputWidth
			height: Typography.fontSize24

			Label {
				anchors.centerIn: parent
				text: root.context.failureMessage
				visible: !root.isLoading && root.context.showFailure && root.context.failureMessage !== ""
				font.pixelSize: Typography.fontSize16
				font.weight: Font.Normal
				color: Colors.textError
			}
		}
	}
}
