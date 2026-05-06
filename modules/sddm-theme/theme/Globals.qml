pragma Singleton

import QtQuick

// Shared SDDM auth state — multiple Main.qml instances render per screen
// (Variants pattern), so password text + loading flag live here so they stay
// in sync across screens.
QtObject {
    property string authPassword: ""
    property bool authLoading: false
    property bool authErrorVisible: false
    property string authErrorMessage: ""
    property string authAttemptKind: ""
    property string authInputOwner: ""
    property string authQueuedAttemptKind: ""
    property string authQueuedPassword: ""
    // Silent = attempt runs without UI feedback (no spinner, input stays editable, no error on fail).
    // Used for auto-submit-on-typing and the first howdy face attempt on greeter open.
    property bool authSilent: false
    property bool authQueuedSilent: false
}
