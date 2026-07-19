import QtQuick
import "../base"

// Inner chrome for keyboard-driven launcher overlays
// (AppLauncher, ClipboardHistory, EmojiPicker).
//
// The hosting PanelWindow stays in the parent file: PanelWindow cannot be a QML component root.
// Wrap with:
//
//   PanelWindow {
//       visible: scope.open
//       WlrLayershell.namespace: "quickshell-foo"
//       focusable: true
//       color: "transparent"
//       anchors { top:true; left:true; right:true; bottom:true }
//       LauncherPanel {
//           anchors.fill: parent
//           searchText: scope.searchText
//           onSearchEdited: text => scope.searchText = text
//           ...
//           ListView { ... }   // default content
//       }
//   }
//
// No animations, deliberate: matches AppLauncher's snappy feel.
Item {
    id: root
    focus: true

    property string searchText: ""
    property string placeholder: "Suchen..."
    property int panelWidth: 500
    property int searchBarHeight: 40
    property bool searchAccent: true
    property bool emptyVisible: false
    property string emptyText: "Keine Ergebnisse"

    default property alias contentData: contentSlot.data

    signal accepted
    signal navigated(int dx, int dy)
    signal pageChange(int dy)
    signal escaped
    signal searchEdited(string text)

    Keys.onPressed: event => {
        const k = event.key;
        const ctrl = event.modifiers & Qt.ControlModifier;
        let next = root.searchText;
        if (k === Qt.Key_Escape) {
            root.escaped();
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            root.accepted();
        } else if (k === Qt.Key_Down || k === Qt.Key_Up) {
            root.navigated(0, k === Qt.Key_Down ? 1 : -1);
        } else if (k === Qt.Key_Right || k === Qt.Key_Left) {
            root.navigated(k === Qt.Key_Right ? 1 : -1, 0);
        } else if (k === Qt.Key_PageDown || k === Qt.Key_PageUp) {
            root.pageChange(k === Qt.Key_PageDown ? 1 : -1);
        } else if (k === Qt.Key_Backspace) {
            next = ctrl ? root.searchText.replace(/\S+\s*$/, "") : root.searchText.slice(0, -1);
        } else if (k === Qt.Key_Delete || (k === Qt.Key_A && ctrl)) {
            next = "";
        } else if (event.text && event.text.length > 0 && !ctrl) {
            next = root.searchText + event.text;
        }
        if (next !== root.searchText)
            root.searchEdited(next);
        event.accepted = true;
    }

    // Dismiss on click outside the panel.
    // Sits under the panel, so the panel's own MouseArea eats clicks inside the panel first.
    // MouseArea, not TapHandler: PointerHandlers attached to a parent fire
    // even when a descendant handled the gesture,
    // closing the panel on every legit click (delegate, category button).
    // MouseArea's "eventually accept" model hit-tests properly.
    MouseArea {
        anchors.fill: parent
        onClicked: root.escaped()
    }

    Rectangle {
        id: panel
        width: root.panelWidth
        height: contentColumn.implicitHeight + 2 * Spacing.spacing12
        anchors.centerIn: parent

        radius: Spacing.spacing12
        color: Colors.pillBackground
        border.width: Shape.usesBlur ? 1 : Shape.thinBorderWidth
        border.color: Colors.pillBorder

        // Click-eater: absorbs clicks on panel padding,
        // else they bubble out to the dismiss MouseArea.
        // Descendant TapHandlers (delegates, category cells) still fire.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: contentColumn
            anchors {
                fill: parent
                margins: Spacing.spacing12
            }
            spacing: Spacing.spacing8

            LauncherSearchBar {
                width: parent.width
                height: root.searchBarHeight
                text: root.searchText
                placeholder: root.placeholder
                accent: root.searchAccent
            }

            Item {
                id: contentSlot
                width: parent.width
                implicitHeight: childrenRect.height
            }

            Label {
                visible: root.emptyVisible
                text: root.emptyText
                font.weight: Font.Normal
                color: Colors.textColorMuted
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: Spacing.spacing8
                bottomPadding: Spacing.spacing8
            }
        }
    }
}
