import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower

ShellRoot {
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // Note: SystemTray and UPower are singletons, accessed directly
    // e.g., SystemTray.items, UPower.displayDevice

    PanelWindow {
        anchors {
            left: true
            right: true
            top: true
        }

        height: 36
        color: "#1e1e2e"

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 12

            // Workspaces section
            RowLayout {
                spacing: 4

                Repeater {
                    model: Hyprland.workspaces

                    Rectangle {
                        required property var modelData

                        width: 30
                        height: 24
                        radius: 4
                        color: modelData.id === Hyprland.focusedWorkspace?.id ? "#89b4fa" : "#313244"
                        
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.id
                            color: "#cdd6f4"
                            font.pixelSize: 12
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // System tray
            RowLayout {
                spacing: 8
                
                Repeater {
                    model: systemTray.items

                    Item {
                        required property var modelData
                        
                        width: 20
                        height: 20

                        Image {
                            anchors.fill: parent
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: modelData.activate()
                        }
                    }
                }
            }

            // Battery indicator
            RowLayout {
                visible: upower.displayDevice.isLaptopBattery
                spacing: 4

                Text {
                    text: "🔋"
                    color: "#cdd6f4"
                    font.pixelSize: 14
                }

                Text {
                    text: Math.round(upower.displayDevice.percentage) + "%"
                    color: upower.displayDevice.percentage < 20 ? "#f38ba8" : "#cdd6f4"
                    font.pixelSize: 12
                }
            }

            // Clock
            Text {
                text: Qt.formatDateTime(clock.date, "hh:mm:ss")
                color: "#cdd6f4"
                font.pixelSize: 12
                font.bold: true
            }
        }
    }
}
