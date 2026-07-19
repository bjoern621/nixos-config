import QtQuick
import "../../"

// Classic glass card: translucent fill, hairline border. Children fill it.
Rectangle {
    default property alias content: holder.data

    radius: Shape.cardRadius
    color: Colors.pillBackground
    border.width: Shape.borderWidth
    border.color: Colors.pillBorder

    Item {
        id: holder
        anchors.fill: parent
    }
}
