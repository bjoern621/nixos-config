import QtQuick
import Quickshell
import Quickshell.Services.Pam

// Shared authentication state for all lock surfaces. Based on the official
// Quickshell lockscreen example's LockContext, extended with a face-unlock
// attempt that routes through the same PAM stack as the SDDM login.
Scope {
	id: root

	signal unlocked()

	// State lives here, not in the per-screen surfaces, so every monitor renders
	// the same password buffer and status.
	property string currentText: ""
	property bool showFailure: false
	property string failureMessage: ""

	// Derived from PAM, never mirrored.
	// pam.start() returns false and emits no signal when the stack cannot start:
	// config dir not a directory, config file missing, getpwuid_r failure.
	// Mirrored flag would stick true forever there, disabling field and buttons
	// with no timeout and no escape, recoverable only from a TTY.
	// abortConversation() emits activeChanged before completed, so this clears
	// before the handler below runs.
	readonly property bool unlockInProgress: pam.active

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

	// Instance is resident and reused across lock cycles: shell.qml does not quit
	// on unlock, so a previous password buffer and failure text outlive it.
	// unlockInProgress needs no reset, it tracks pam.active.
	function reset() {
		currentText = "";
		showFailure = false;
		failureMessage = "";
		attemptKind = "";
	}

	function tryPassword() {
		if (unlockInProgress || currentText === "") return;
		attemptKind = "password";
		showFailure = false;
		pam.start();
	}

	function tryFace() {
		if (unlockInProgress) return;
		attemptKind = "face";
		showFailure = false;
		pam.start();
	}

	function tryPasskey() {
		if (unlockInProgress) return;
		attemptKind = "passkey";
		showFailure = false;
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

		// Sole outcome handler, PamResult.Error included.
		// PamContext emits error() then completed(PamResult.Error), synchronously.
		// Separate onError would report twice and lose its message to this branch.
		onCompleted: result => {
			// Plaintext outlives unlock otherwise.
			// Process stays resident.
			// Lid close hibernates via before_sleep_cmd, snapshotting heap to disk.
			// Assign before showFailure: onCurrentTextChanged clears it.
			root.currentText = "";

			if (result === PamResult.Success) {
				root.attemptKind = "";
				root.unlocked();
				return;
			}

			// PamResult.Error is a stack/plumbing failure, not a rejected credential.
			// Naming the attempt would blame the password for a camera or howdy fault.
			root.failureMessage = result === PamResult.Error
				? "Authentifizierung fehlgeschlagen"
				: root.attemptKind === "face"
				? "Gesicht nicht erkannt"
				: root.attemptKind === "passkey"
				? "Schlüssel nicht erkannt"
				: "Falsches Passwort";
			root.showFailure = true;
			// Clear last: message above reads it.
			root.attemptKind = "";
		}
	}
}
