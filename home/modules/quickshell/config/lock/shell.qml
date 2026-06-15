import Quickshell
import Quickshell.Wayland

// Session lock entry point. Follows the official Quickshell lockscreen example
// (quickshell-examples/lockscreen): one shared LockContext, a WlSessionLock that
// locks immediately, and a per-screen WlSessionLockSurface.
ShellRoot {
	// Shared state across every per-screen lock surface.
	LockContext {
		id: lockContext

		onUnlocked: {
			// Release the lock before exiting. If the process dies while still
			// locked, a conformant compositor keeps the screen locked and painted
			// solid, leaving the session unusable until a TTY login. Order matters:
			// unlock, then quit.
			lock.locked = false;
			Qt.quit();
		}
	}

	WlSessionLock {
		id: lock

		// Engage the lock the moment Quickshell starts this config.
		locked: true

		WlSessionLockSurface {
			LockSurface {
				anchors.fill: parent
				context: lockContext
			}
		}
	}
}
