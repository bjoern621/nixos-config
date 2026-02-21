// ============================================================================
// WifiPopup - Expandable WiFi Network List Popup
// Hover expansion showing available networks
// ============================================================================

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../Theme.js" as Theme

PopupWindow {
    id: wifiPopup
    
    // Position relative to wifi indicator
    anchor {
        item: wifiIndicator
        rect: Qt.rect(0, 0, wifiIndicator.width, wifiIndicator.height)
    }
    anchor.window: panelWindow
    anchor.edges: Edges.Bottom
    
    // Size
    implicitWidth: 320
    implicitHeight: Math.min(400, networkList.contentHeight + 80)
    
    // Styling
    color: "transparent"
    visible: false
    
    // Close when clicking outside
    onVisibleChanged: {
        if (visible) {
            closeTimer.stop()
            // Refresh networks when opening
            refreshNetworks()
        }
    }
    
    // Auto-close timer
    Timer {
        id: closeTimer
        interval: 3000
        running: !wifiMouseArea.containsMouse && !popupMouseArea.containsMouse
        onTriggered: wifiPopup.visible = false
    }
    
    // Refresh timer
    Timer {
        id: refreshTimer
        interval: 5000
        running: visible
        repeat: true
        onTriggered: refreshNetworks()
    }
    
    function refreshNetworks() {
        wifiScanner.running = true
    }
    
    Rectangle {
        id: popupContainer
        anchors.fill: parent
        anchors.margins: Theme.spacingSmall
        
        // Styling
        radius: Theme.radiusLarge
        color: Theme.withAlpha(Theme.bgSurface, 0.95)
        border.width: 1
        border.color: Theme.withAlpha(Theme.bgBorder, 0.5)
        
        // Drop shadow
        layer.enabled: true
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingMedium
            spacing: Theme.spacingMedium
            
            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium
                
                Text {
                    text: "󰤨"
                    color: wifiConnected ? Theme.wifiConnected : Theme.wifiDisconnected
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconSizeLarge
                }
                
                Text {
                    text: "WiFi"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Theme.fontWeightMedium
                }
                
                Item { Layout.fillWidth: true }
                
                // Refresh button
                Rectangle {
                    width: 32
                    height: 32
                    radius: Theme.radiusSmall
                    color: refreshButtonArea.containsMouse ? Theme.bgActive : Theme.bgHover
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.iconSizeMedium
                        
                        // Spinning animation when refreshing
                        RotationAnimation on rotation {
                            running: wifiScanner.running
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                        }
                    }
                    
                    MouseArea {
                        id: refreshButtonArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: refreshNetworks()
                    }
                }
            }
            
            // Current connection
            Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: Theme.radiusMedium
                color: Theme.bgHover
                visible: wifiConnected
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: Theme.spacingMedium
                    
                    Text {
                        text: "󰤨"
                        color: Theme.wifiConnected
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.iconSizeMedium
                    }
                    
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        
                        Text {
                            text: wifiSsid
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Theme.fontWeightMedium
                        }
                        
                        Text {
                            text: "Connected"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                    
                    // Signal strength
                    Text {
                        text: getSignalIcon(wifiSignal)
                        color: Theme.wifiConnected
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.iconSizeMedium
                        
                        function getSignalIcon(strength) {
                            if (strength > 80) return "󰤨"
                            if (strength > 60) return "󰤥"
                            if (strength > 40) return "󰤢"
                            if (strength > 20) return "󰤟"
                            return "󰤯"
                        }
                    }
                }
            }
            
            // Separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.bgBorder
                visible: wifiConnected
            }
            
            // Available networks
            Text {
                text: "Available Networks"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                visible: availableNetworks.count > 0
            }
            
            // Network list
            ListView {
                id: networkList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.spacingSmall
                
                model: availableNetworks
                delegate: Rectangle {
                    width: networkList.width
                    height: 44
                    radius: Theme.radiusMedium
                    color: networkMouseArea.containsMouse ? Theme.bgActive : Theme.bgHover
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMedium
                        spacing: Theme.spacingMedium
                        
                        // Security icon
                        Text {
                            text: modelData.secure ? "󰌾" : "󰤪"
                            color: modelData.secure ? Theme.textSecondary : Theme.accentOrange
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.iconSizeSmall
                        }
                        
                        // Network name
                        Text {
                            text: modelData.ssid
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        
                        // Signal strength
                        Text {
                            text: getSignalIcon(modelData.signal)
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.iconSizeMedium
                            
                            function getSignalIcon(strength) {
                                if (strength > 80) return "󰤨"
                                if (strength > 60) return "󰤥"
                                if (strength > 40) return "󰤢"
                                if (strength > 20) return "󰤟"
                                return "󰤯"
                            }
                        }
                    }
                    
                    MouseArea {
                        id: networkMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            // Connect to network (would need nmcli integration)
                            console.log("Connect to:", modelData.ssid)
                        }
                    }
                }
                
                // Empty state
                Text {
                    anchors.centerIn: parent
                    text: wifiScanner.running ? "Scanning..." : "No networks found"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    visible: availableNetworks.count === 0
                }
            }
        }
        
        MouseArea {
            id: popupMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }
    
    // Animation
    Behavior on implicitHeight {
        NumberAnimation { 
            duration: Theme.animationMedium 
            easing.type: Easing.OutCubic
        }
    }
}
