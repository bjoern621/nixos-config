pragma Singleton
import QtQuick

QtObject {
    readonly property string fontFamily: "Inter"
    readonly property string iconFontFamily: "Font Awesome 7 Free Solid"
    readonly property font fontBold: Qt.font({ family: fontFamily, weight: Font.Bold })
    readonly property int fontSize12: 12
    readonly property int fontSize14: 14
    readonly property int fontSize16: 16
    readonly property int fontSize20: 20
    readonly property int fontSize24: 24
}
