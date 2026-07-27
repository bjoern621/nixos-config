pragma ComponentBehavior: Bound

import QtQuick
import "../"
import "../base"

// Key/value facts in a device detail panel. Rows come from
// NetworkUtils.deviceDetailRows, so wifi and wired stay in step and a new fact
// is one entry there.
// Caller sets an explicit width; children track it.
Column {
    id: root

    property var rows: []
    property int labelWidth: 84

    spacing: 2

    Repeater {
        model: root.rows

        Row {
            id: factRow
            required property var modelData

            width: root.width
            spacing: Spacing.spacing8

            Label {
                width: root.labelWidth
                text: factRow.modelData.label
                font.pixelSize: Typography.fontSize12
                font.weight: Font.Normal
                color: Colors.textColorMuted
                elide: Text.ElideRight
            }
            Label {
                // Wraps rather than elides: a v6 address outruns the column and
                // its tail is the part that identifies the host.
                width: factRow.width - root.labelWidth - factRow.spacing
                text: factRow.modelData.value
                font.pixelSize: Typography.fontSize12
                wrapMode: Text.WrapAnywhere
            }
        }
    }
}
