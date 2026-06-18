import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

// Lock surface, rendered once per screen. The visual face is the shared
// LoginPanel, also used by the SDDM login theme (modules/sddm-theme/theme/
// Main.qml). Authentication is delegated to the shared LockContext, so the
// login look is reused without reusing the login logic.
Rectangle {
	id: root

	required property LockContext context

	color: Colors.background

	// The lock runs under Hyprland (eDP-1 at scale 2, home/modules/hyprland/
	// monitors.nix) but the SDDM login theme runs under kwin, which renders the
	// same fixed px values at a different per-output scale. Left uncompensated,
	// every element on the lock appears 2/1.6 = 1.25x larger than on the greeter.
	// Match the greeter by scaling the panel content so each design unit lands on
	// the same number of physical pixels as SDDM, on every monitor.
	//
	// greeterScale: the scale kwin auto-picks for the greeter on each output,
	// persisted in /var/lib/sddm/.config/kwinoutputconfig.json. Unlisted outputs
	// fall back to the surface's own scale, which leaves the content unscaled.
	readonly property real greeterScale: {
		switch (Screen.name) {
		case "eDP-1":
			return 1.6;
		default:
			return Screen.devicePixelRatio;
		}
	}
	readonly property real uiScale: greeterScale / Screen.devicePixelRatio

	LoginPanel {
		id: panel
		anchors.fill: parent
		contentScale: root.uiScale

		userName: Quickshell.env("USER") || "Benutzer"
		loading: root.context.unlockInProgress
		loadingMessage: root.context.attemptKind === "face" ? "Gesicht wird erkannt…" : "Wird überprüft…"
		failureMessage: root.context.failureMessage
		failureVisible: root.context.showFailure
		passwordText: root.context.currentText

		// Keep every monitor's field in sync via the shared buffer.
		onPasswordEdited: text => root.context.currentText = text
		onPasswordSubmitted: root.context.tryPassword()
		onFaceRequested: root.context.tryFace()

		// forceActiveFocus is scoped to each surface's own window, so the compositor
		// still routes keys to the focused monitor; the shared buffer keeps every
		// field's text in sync.
		Component.onCompleted: focusPassword()
	}
}
