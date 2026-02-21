// ============================================================================
// AudioPopup - Expandable Volume Control Popup
// Hover expansion with icon, slider, and percentage display
// ============================================================================

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../Theme.js" as Theme

PopupWindow {
    id: audioPopup
    
    // Position relative to audio indicator
    anchor {
        item: audioIndicator
        rect: Qt.rect(0, 0, audioIndicator.width, audioIndicator.height)
    }
    anchor.window: panelWindow
    anchor.edges: Edges.Bottom
    
    // Size
    implicitWidth: 280
    implicitHeight: 120
    
    // Styling
    color: "transparent"
    visible: false
    
    // Close when clicking outside
    onVisibleChanged: {
        if (visible) {
            closeTimer.stop()
        }
    }
    
    // Auto-close timer
    Timer {
        id: closeTimer
        interval: 3000
        running: !audioMouseArea.containsMouse && !popupMouseArea.containsMouse
        onTriggered: audioPopup.visible = false
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
        
        // Content
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingMedium
            spacing: Theme.spacingMedium
            
            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium
                
                Text {
                    text: "󰕾"
                    color: muted ? Theme.audioMuted : Theme.audioHigh
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconSizeLarge
                }
                
                Text {
                    text: "Audio"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Theme.fontWeightMedium
                }
                
                Item { Layout.fillWidth: true }
                
                // Mute button
                Rectangle {
                    width: 32
                    height: 32
                    radius: Theme.radiusSmall
                    color: muteButtonArea.containsMouse ? Theme.bgActive : Theme.bgHover
                    
                    Text {
                        anchors.centerIn: parent
                        text: muted ? "󰝟" : "󰕾"
                        color: muted ? Theme.accentRed : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.iconSizeMedium
                    }
                    
                    MouseArea {
                        id: muteButtonArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: muted = !muted
                    }
                }
            }
            
            // Volume slider
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium
                
                // Low volume icon
                Text {
                    text: "󰕿"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconSizeSmall
                }
                
                // Slider track
                Rectangle {
                    Layout.fillWidth: true
                    height: 8
                    radius: 4
                    color: Theme.bgHover
                    
                    // Filled portion
                    Rectangle {
                        width: parent.width * volume
                        height: parent.height
                        radius: parent.radius
                        color: muted ? Theme.audioMuted : Theme.accentBlue
                        
                        Behavior on width {
                            NumberAnimation { 
                                duration: Theme.animationFast 
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    
                    // Slider handle
                    Rectangle {
                        x: parent.width * volume - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 8
                        color: Theme.textPrimary
                        
                        Behavior on x {
                            NumberAnimation { 
                                duration: Theme.animationFast 
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        // Handle shadow
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: parent.radius + 2
                            color: Theme.withAlpha(Theme.bgBase, 0.3)
                            z: -1
                        }
                    }
                    
                    MouseArea {
                        id: sliderArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        function updateVolume(mouseX) {
                            var newVolume = Math.max(0, Math.min(1, mouseX / width))
                            volume = newVolume
                        }
                        
                        onPressed: updateVolume(mouseX)
                        onPositionChanged: {
                            if (pressed) updateVolume(mouseX)
                        }
                    }
                }
                
                // High volume icon
                Text {
                    text: "󰕾"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconSizeSmall
                }
                
                // Percentage display
                Text {
                    text: Math.round(volume * 100) + "%"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Theme.fontWeightMedium
                    Layout.minimumWidth: 45
                    horizontalAlignment: Text.AlignRight
                }
            }
            
            // Output device info
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSmall
                
                Text {
                    text: "󰓃"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconSizeSmall
                }
                
                Text {
                    text: audioDevice || "Default Output"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    Layout.fillWidth: true
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
