import QtQuick
import "../base"

// Inner chrome for keyboard-driven launcher overlays
// (AppLauncher, ClipboardHistory, EmojiPicker).
//
// The hosting PanelWindow stays in the parent file: PanelWindow cannot be a QML component root.
// The three overlays share one window shape. The rules it enforces (card-sized
// surface, fixed height, dismissal, scrolling, selection) are in the
// "Launcher Overlays" section of the repo CLAUDE.md.
//
//   PanelWindow {
//       id: fooWindow
//       visible: scope.open
//       WlrLayershell.namespace: "quickshell-foo"
//       focusable: true
//       color: "transparent"
//       // No anchors: the compositor centers a card-sized surface.
//       implicitWidth: panel.surfaceWidth
//       implicitHeight: panel.surfaceHeight
//       WlrLayershell.keyboardFocus: scope.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
//
//       LauncherDismiss {
//           hostWindow: fooWindow
//           watch: panel
//           active: scope.open
//           onDismissed: scope.open = false
//       }
//
//       LauncherPanel {
//           id: panel
//           anchors.fill: parent
//           searchText: scope.searchText
//           contentMaxHeight: <view at its tallest>
//           onSearchEdited: text => scope.searchText = text
//           ...
//           LauncherListView { ... }   // default content
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

    // Content slot at its tallest, set by the consumer from the same constants
    // that cap its view. Surface is sized from this, so a short result set
    // leaves transparent slack instead of resizing the layer per keystroke.
    property int contentMaxHeight: 0

    readonly property bool neo: !Shape.usesBlur
    // Neo header matches AppLauncherNeo: 50px flush, ink divider beneath.
    readonly property int neoHeaderHeight: 50
    // Y distance from panel top to the content column (header block above it).
    readonly property int headerBlock: neo ? (neoHeaderHeight + Shape.borderWidth + Spacing.spacing8) : (Spacing.spacing12 + searchBarHeight + Spacing.spacing8)

    // Panel hugs its content; the surface holds the upper bound.
    // Live height wins over a too-small contentMaxHeight, so a stale bound
    // costs a resize instead of clipping the panel.
    readonly property int panelHeight: headerBlock + contentColumn.implicitHeight + Spacing.spacing12
    readonly property int panelMaxHeight: headerBlock + Math.max(contentMaxHeight, contentColumn.implicitHeight) + Spacing.spacing12

    // Layer surface size. Host binds implicitWidth/implicitHeight to these.
    // Neo offsets panel and shadow by half the shadow distance each, so the
    // pair spans one shadow distance more than the panel itself.
    readonly property int surfaceWidth: panelWidth + Shape.shadowOffset
    readonly property int surfaceHeight: panelMaxHeight + Shape.shadowOffset

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

    // Dismiss on click in the surface slack around the panel (shadow offset,
    // and the vertical gap left when the content is shorter than contentMaxHeight).
    // Clicks fully outside the surface never arrive; LauncherDismiss closes those.
    // Sits under the panel, so the panel's own MouseArea eats clicks inside the panel first.
    // MouseArea, not TapHandler: PointerHandlers attached to a parent fire
    // even when a descendant handled the gesture,
    // closing the panel on every legit click (delegate, category button).
    // MouseArea's "eventually accept" model hit-tests properly.
    MouseArea {
        anchors.fill: parent
        onClicked: root.escaped()
    }

    // Neo hard offset shadow: solid, no blur, down-right. Classic: shadowOffset 0, hidden.
    // Panel and shadow each shift by half the offset so the pair stays centered.
    Rectangle {
        visible: Shape.shadowOffset > 0
        width: panel.width
        height: panel.height
        radius: panel.radius
        color: Colors.separatorColor
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: Shape.shadowOffset / 2
        anchors.verticalCenterOffset: Shape.shadowOffset / 2
    }

    Rectangle {
        id: panel
        width: root.panelWidth
        height: root.panelHeight
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -Shape.shadowOffset / 2
        anchors.verticalCenterOffset: -Shape.shadowOffset / 2

        radius: Shape.usesBlur ? Spacing.spacing12 : Shape.cardRadius
        color: Colors.pillBackground
        border.width: Shape.usesBlur ? 1 : Shape.borderWidth
        border.color: Colors.pillBorder

        // Click-eater: absorbs clicks on panel padding,
        // else they bubble out to the dismiss MouseArea.
        // Descendant TapHandlers (delegates, category cells) still fire.
        MouseArea {
            anchors.fill: parent
        }

        // Header. Classic: rounded box inset 12px.
        // Neo: flush full-width 50px header, followed by the flush ink divider.
        LauncherSearchBar {
            id: searchBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: root.neo ? 0 : Spacing.spacing12
            anchors.leftMargin: root.neo ? 0 : Spacing.spacing12
            anchors.rightMargin: root.neo ? 0 : Spacing.spacing12
            height: root.neo ? root.neoHeaderHeight : root.searchBarHeight
            text: root.searchText
            placeholder: root.placeholder
            accent: root.searchAccent
        }

        // Neo: full-bleed ink divider under the header (app-launcher style).
        Rectangle {
            id: headerDivider
            visible: root.neo
            anchors.top: searchBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: Shape.borderWidth
            color: Colors.separatorColor
        }

        Column {
            id: contentColumn
            anchors.top: root.neo ? headerDivider.bottom : searchBar.bottom
            anchors.topMargin: Spacing.spacing8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Spacing.spacing12
            anchors.rightMargin: Spacing.spacing12
            spacing: Spacing.spacing8

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
