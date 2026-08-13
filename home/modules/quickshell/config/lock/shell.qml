import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Session lock entry point. Runs as a resident process (systemd user service
// quickshell-lock, see quickshell.nix), started at login and kept alive across
// lock cycles. It sits idle with locked = false, which creates no lock surfaces
// and therefore no Wayland layer surfaces. Locking is a state flip driven over
// IPC by the `quickshell-lock` command.
//
// Resident, rather than cold-spawned per lock, on purpose: spawning a fresh
// Quickshell during the suspend/hibernate window races the freeze and the GPU
// re-init on resume. A frozen, half-initialized lock process used to die on
// resume with no surface, leaving Hyprland's "lock app died" fallback. An
// already-initialized, Wayland-connected process just maps a surface instead.
ShellRoot {
	// Shared state across every per-screen lock surface.
	LockContext {
		id: lockContext

		// Release the lock and stay resident for the next cycle. Setting locked
		// false destroys the surfaces; the process keeps running so the next lock
		// is an instant state flip rather than a cold start.
		onUnlocked: lock.locked = false
	}

	WlSessionLock {
		id: lock

		// Idle until an IPC lock call arrives. While false, no WlSessionLockSurface
		// is instantiated, so there is nothing for the compositor to composite.
		locked: false

		// USB hotplug authorization follows the lock (home/modules/usbguard.nix).
		// Locked drops the catch-all rule, leaving only the seeded allowlist, so a
		// keyboard emulator plugged into the locked machine never binds.
		// Fire-and-forget: the lock must not wait on the IPC round trip.
		onLockedChanged: Quickshell.execDetached([
			"usbguard-session-policy",
			locked ? "locked" : "unlocked",
		])

		WlSessionLockSurface {
			LockSurface {
				anchors.fill: parent
				context: lockContext
			}
		}
	}

	// Lock trigger. The `quickshell-lock` command runs
	// `quickshell ipc ... call lock lock`, which engages the lock. Idempotent: a
	// repeated call while already locked is a no-op, so stacked lock-session
	// signals (e.g. manual lock plus before-sleep) never double up.
	IpcHandler {
		target: "lock"

		function lock(): void {
			if (lock.locked)
				return;
			lockContext.reset();
			lock.locked = true;
		}
	}
}
