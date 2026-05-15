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
}
