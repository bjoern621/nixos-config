import QtQuick
import Quickshell

// Test harness: renders the lock surface in a normal window instead of a real
// session lock, so the layout and auth flow can be checked without locking the
// session. Run with: quickshell -p test.qml
ShellRoot {
	LockContext {
		id: lockContext
		onUnlocked: Qt.quit()
	}

	FloatingWindow {
		LockSurface {
			anchors.fill: parent
			context: lockContext
		}
	}

	Connections {
		target: Quickshell
		function onLastWindowClosed() {
			Qt.quit();
		}
	}
}
