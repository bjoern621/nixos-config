import QtQuick
import Quickshell
import Quickshell.Services.Pam

// Shared authentication state for all lock surfaces. Based on the official
// Quickshell lockscreen example's LockContext, extended with a face-unlock
// attempt that routes through the same PAM stack as the SDDM login.
Scope {
	id: root

	signal unlocked()
	signal failed()

	// State lives here, not in the per-screen surfaces, so every monitor renders
	// the same password buffer and status.
	property string currentText: ""
	property bool unlockInProgress: false
	property bool showFailure: false
	property string failureMessage: ""

	// Which attempt is in flight: "password", "face" or "passkey". Determines what
	// gets sent to PAM when it asks for a response, and which failure message to
	// show.
	property string attemptKind: ""

	// Sentinel response sent for a passkey attempt. The PAM stack
	// (modules/quickshell-lock.nix) routes it to pam_u2f, mirroring how the SDDM
	// login encodes the same intent. Not a secret; the key still gates.
	readonly property string passkeySentinel: "__fido2_passkey__"

	// Clear the failure text once the user starts typing again.
	onCurrentTextChanged: showFailure = false

	// Reset transient state before a fresh lock. The instance is resident and
	// reused across lock cycles (shell.qml does not quit on unlock), so the
	// password buffer and failure text from a previous unlock must be cleared
	// before the next lock surface appears.
	function reset() {
		currentText = "";
		showFailure = false;
		failureMessage = "";
	}

	function tryPassword() {
		if (unlockInProgress || currentText === "") return;
		attemptKind = "password";
		showFailure = false;
		unlockInProgress = true;
		pam.start();
	}

	function tryFace() {
		if (unlockInProgress) return;
		attemptKind = "face";
		showFailure = false;
		unlockInProgress = true;
		pam.start();
	}

	function tryPasskey() {
		if (unlockInProgress) return;
		attemptKind = "passkey";
		showFailure = false;
		unlockInProgress = true;
		pam.start();
	}

	PamContext {
		id: pam

		// Custom stack (modules/quickshell-lock.nix). Routes an empty password to
		// howdy face recognition and a typed password to pam_unix, mirroring the
		// SDDM login. configDirectory defaults to /etc/pam.d.
		config: "quickshell-lock"

		// pam_unix prompts once for the password. Send the typed text for a
		// password attempt, or an empty string for a face attempt (which the PAM
		// stack detects and reroutes to howdy).
		onPamMessage: {
			if (this.responseRequired) {
				this.respond(root.attemptKind === "face" ? ""
						: root.attemptKind === "passkey" ? root.passkeySentinel
						: root.currentText);
			}
		}

		onCompleted: result => {
			if (result === PamResult.Success) {
				root.unlocked();
			} else {
				root.currentText = "";
				root.failureMessage = root.attemptKind === "face"
					? "Gesicht nicht erkannt"
					: root.attemptKind === "passkey"
					? "Schlüssel nicht erkannt"
					: "Falsches Passwort";
				root.showFailure = true;
				root.failed();
			}
			root.unlockInProgress = false;
			root.attemptKind = "";
		}

		onError: error => {
			root.currentText = "";
			root.failureMessage = "Authentifizierung fehlgeschlagen";
			root.showFailure = true;
			root.unlockInProgress = false;
			root.attemptKind = "";
			root.failed();
		}
	}
}
