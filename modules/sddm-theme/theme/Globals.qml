pragma Singleton

import QtQuick

QtObject {
    property color accentColor: "#ffffff"

    // Shared SDDM auth state across all screen instances.
    property string authPassword: ""
    property bool authLoading: false
    property bool authErrorVisible: false
    property string authErrorMessage: ""
    property string authAttemptKind: ""
    property string authInputOwner: ""
    property string authQueuedAttemptKind: ""
    property string authQueuedPassword: ""
}
