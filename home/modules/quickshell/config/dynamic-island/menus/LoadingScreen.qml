import QtQuick
import Quickshell
import "../"
import "../animations"

Item {
    id: root

    property bool showing: false
    property string actionLabel: ""
    signal cancelled()
    signal hidden()

    opacity: 0
    visible: opacity > 0
    scale: 0.96
    focus: visible

    transformOrigin: Item.Center

    Keys.onEscapePressed: root.cancelled()

    transform: Translate {
        id: slideTransform
        y: Spacing.spacing8
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)

        // Exit button - invisible until hovered
        Rectangle {
            id: exitButton
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Spacing.spacing24
            width: 40
            height: 40
            radius: height / 2
            opacity: exitHover.hovered ? 1 : 0
            color: exitTap.pressed ? Colors.hoverItemPressed
                 : exitHover.hovered ? Colors.hoverItemHovered
                 : "transparent"
            border.color: exitHover.hovered || exitTap.pressed ? Colors.pillBorder : "transparent"

            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            scale: exitTap.pressed ? 0.85 : 1.0
            SquishBehavior on scale {}

            Text {
                anchors.centerIn: parent
                text: "\uf00d"
                font.family: Typography.iconFontFamily
                font.pixelSize: Typography.fontSize16
                color: Colors.textColor
            }

            HoverHandler {
                id: exitHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: exitTap
                onTapped: root.cancelled()
            }
        }

        // Loading content
        Column {
            anchors.centerIn: parent
            spacing: Spacing.spacing24

            Item {
                id: loadingCircle
                width: 60
                height: 60
                anchors.horizontalCenter: parent.horizontalCenter

                Canvas {
                    id: spinnerCanvas
                    anchors.fill: parent
                    
                    property real angle: 0
                    property real sweep: 0

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = Colors.accentColor
                        ctx.lineWidth = 6
                        ctx.lineCap = "round"
                        
                        var centerX = width / 2
                        var centerY = height / 2
                        var radius = width / 2 - 4
                        
                        // Draw arc with current angle and sweep
                        var startAngle = (angle - 90) * Math.PI / 180
                        var endAngle = (angle + sweep - 90) * Math.PI / 180
                        
                        ctx.beginPath()
                        ctx.arc(centerX, centerY, radius, startAngle, endAngle)
                        ctx.stroke()
                    }

                    // Smooth rotation animation
                    NumberAnimation on angle {
                        from: 0
                        to: 360
                        duration: 1800
                        loops: Animation.Infinite
                        running: root.visible
                        easing.type: Easing.Linear
                    }

                    // Smooth sweep animation - different duration creates variation
                    SequentialAnimation on sweep {
                        running: root.visible
                        loops: Animation.Infinite
                        
                        NumberAnimation {
                            from: 30
                            to: 240
                            duration: 2100
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: 240
                            to: 30
                            duration: 2100
                            easing.type: Easing.InOutSine
                        }
                    }

                    onAngleChanged: requestPaint()
                    onSweepChanged: requestPaint()
                    
                    Component.onCompleted: requestPaint()
                }
            }

            // Action label
            Text {
                id: actionText
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.actionLabel
                font.family: Typography.fontFamily
                font.weight: Font.Bold
                font.pixelSize: Typography.fontSize16
                color: Colors.textColor
            }
        }
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { target: slideTransform; property: "y"; to: 0; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "scale"; to: 1.0; duration: 250; easing.type: Easing.OutBack }
    }

    ParallelAnimation {
        id: hideAnim
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
        NumberAnimation { target: slideTransform; property: "y"; to: Spacing.spacing8; duration: 150; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "scale"; to: 0.96; duration: 150; easing.type: Easing.InCubic }
        onFinished: root.hidden()
    }

    onShowingChanged: {
        if (showing) {
            hideAnim.stop()
            showAnim.start()
        } else {
            showAnim.stop()
            hideAnim.start()
        }
    }

    function show(label) {
        root.actionLabel = label
        root.showing = true
    }

    function hide() {
        root.showing = false
    }
}
