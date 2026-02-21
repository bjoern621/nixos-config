// ============================================================================
// IslandBar - Main Dynamic Island Status Bar
// A centered, floating bar with expandable sections
// ============================================================================

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import ".."

Scope {
    id: root
    
    // Popup visibility state
    property bool audioPopupVisible: false
    property bool wifiPopupVisible: false
    
    // References for popup anchoring
    property var panelWindowRef: null
    property var audioIndicatorRef: null
    property var wifiIndicatorRef: null
    
    // Network state - using native Quickshell.Networking API
    property var wifiDevice: {
        const devices = Networking.devices.values;
        for (const dev of devices) {
            if (dev.type === DeviceType.Wifi) return dev;
        }
        return null;
    }
    property var availableNetworks: wifiDevice?.networks?.values ?? []
    property bool wifiConnected: wifiDevice?.state === DeviceConnectionState.Connected
    property string wifiSsid: wifiDevice?.activeConnection?.ssid ?? ""
    
    Variants {
        model: Quickshell.screens
        
        PanelWindow {
            id: panelWindow
            required property var modelData
            screen: modelData
            
            // Register as active panel
            Component.onCompleted: root.panelWindowRef = this
            
            // Layer configuration
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "dynamic-island"
            exclusionMode: ExclusionMode.Auto
            
            // Positioning - centered at top
            anchors {
                top: true
                left: true
                right: true
            }
            
            implicitHeight: Theme.islandHeight + Theme.spacingLarge * 2
            color: "transparent"
            
            // Main container
            Rectangle {
                id: islandContainer
                anchors.fill: parent
                anchors.margins: Theme.spacingLarge
                color: "transparent"
                
                // Centered island
                Rectangle {
                    id: island
                    anchors.centerIn: parent
                    
                    // Dynamic width based on content
                    width: islandContent.implicitWidth + Theme.islandPadding * 2
                    height: Theme.islandHeight
                    radius: Theme.islandRadius
                    
                    // Glass morphism effect
                    color: Theme.withAlpha(Theme.bgBase, 0.85)
                    border.width: 1
                    border.color: Theme.withAlpha(Theme.bgBorder, 0.5)
                    
                    // Subtle inner shadow
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.textPrimary, 0.05)
                    }
                    
                    // Drop shadow
                    layer.enabled: true
                    layer.effect: Item {
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -8
                            radius: island.radius + 8
                            color: "transparent"
                            z: -1
                            
                            // Shadow layers
                            Repeater {
                                model: 3
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -index * 4
                                    radius: island.radius + 8 + index * 4
                                    color: Theme.withAlpha(Theme.bgBase, 0.1 - index * 0.03)
                                    z: -1
                                }
                            }
                        }
                    }
                    
                    // Content row
                    RowLayout {
                        id: islandContent
                        anchors.centerIn: parent
                        spacing: Theme.spacingMedium
                        
                        // ====================================================================
                        // LEFT: Workspaces
                        // ====================================================================
                        
                        Row {
                            id: workspaceRow
                            spacing: Theme.spacingSmall
                            
                            Repeater {
                                model: Hyprland.workspaces
                                
                                Rectangle {
                                    id: workspacePill
                                    required property var modelData
                                    
                                    width: modelData.focused ? 32 : 24
                                    height: Theme.pillHeight - 8
                                    radius: height / 2
                                    
                                    color: modelData.focused 
                                        ? Theme.accentBlue 
                                        : modelData.urgent 
                                            ? Theme.accentRed 
                                            : Theme.bgHover
                                    
                                    // Smooth transitions
                                    Behavior on width {
                                        NumberAnimation { 
                                            duration: Theme.animationFast 
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    
                                    Behavior on color {
                                        ColorAnimation { 
                                            duration: Theme.animationFast 
                                        }
                                    }
                                    
                                    // Workspace number
                                    Text {
                                        anchors.centerIn: parent
                                        text: workspacePill.modelData.id
                                        color: workspacePill.modelData.focused 
                                            ? Theme.textPrimary 
                                            : Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Theme.fontWeightMedium
                                    }
                                    
                                    // Click to switch
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        
                                        onEntered: workspacePill.color = Theme.bgActive
                                        onExited: workspacePill.color = workspacePill.modelData.focused 
                                            ? Theme.accentBlue 
                                            : workspacePill.modelData.urgent 
                                                ? Theme.accentRed 
                                                : Theme.bgHover
                                        
                                        onClicked: workspacePill.modelData.activate()
                                    }
                                    
                                    // Urgent animation
                                    SequentialAnimation {
                                        running: workspacePill.modelData.urgent && !workspacePill.modelData.focused
                                        loops: Animation.Infinite
                                        
                                        ColorAnimation {
                                            target: workspacePill
                                            property: "color"
                                            to: Theme.accentOrange
                                            duration: 500
                                        }
                                        ColorAnimation {
                                            target: workspacePill
                                            property: "color"
                                            to: Theme.bgHover
                                            duration: 500
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Separator
                        Rectangle {
                            width: 1
                            height: Theme.pillHeight - 12
                            color: Theme.bgBorder
                            Layout.alignment: Qt.AlignVCenter
                        }
                        
                        // ====================================================================
                        // CENTER: Date & Time
                        // ====================================================================
                        
                        Row {
                            id: dateTimeRow
                            spacing: Theme.spacingMedium
                            
                            // Time
                            Text {
                                text: Qt.formatDateTime(clock.date, "HH:mm")
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Theme.fontWeightMedium
                            }
                            
                            // Date
                            Text {
                                text: Qt.formatDateTime(clock.date, "ddd d MMM")
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Theme.fontWeightNormal
                            }
                        }
                        
                        // Separator
                        Rectangle {
                            width: 1
                            height: Theme.pillHeight - 12
                            color: Theme.bgBorder
                            Layout.alignment: Qt.AlignVCenter
                        }
                        
                        // ====================================================================
                        // RIGHT: Status Indicators
                        // ====================================================================
                        
                        Row {
                            id: statusRow
                            spacing: Theme.spacingSmall
                            
                            // Audio indicator
                            Rectangle {
                                id: audioIndicator
                                Component.onCompleted: root.audioIndicatorRef = this
                                
                                width: audioContent.width + Theme.spacingMedium
                                height: Theme.pillHeight - 8
                                radius: height / 2
                                color: audioMouseArea.containsMouse ? Theme.bgActive : Theme.bgHover
                                
                                Row {
                                    id: audioContent
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingSmall
                                    
                                    Text {
                                        text: getVolumeIcon()
                                        color: muted ? Theme.audioMuted : Theme.audioHigh
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.iconSizeMedium
                                        
                                        function getVolumeIcon() {
                                            if (muted || volume === 0) return "󰝟"
                                            if (volume < 0.33) return "󰕿"
                                            if (volume < 0.66) return "󰖀"
                                            return "󰕾"
                                        }
                                    }
                                    
                                    Text {
                                        text: Math.round(volume * 100) + "%"
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                    }
                                }
                                
                                MouseArea {
                                    id: audioMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onClicked: root.audioPopupVisible = !root.audioPopupVisible
                                }
                                
                                Behavior on color {
                                    ColorAnimation { duration: Theme.animationFast }
                                }
                            }
                            
                            // WiFi indicator
                            Rectangle {
                                id: wifiIndicator
                                Component.onCompleted: root.wifiIndicatorRef = this
                                
                                width: wifiContent.width + Theme.spacingMedium
                                height: Theme.pillHeight - 8
                                radius: height / 2
                                color: wifiMouseArea.containsMouse ? Theme.bgActive : Theme.bgHover
                                
                                Row {
                                    id: wifiContent
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingSmall
                                    
                                    Text {
                                        text: getWifiIcon()
                                        color: wifiConnected ? Theme.wifiConnected : Theme.wifiDisconnected
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.iconSizeMedium
                                        
                                        function getWifiIcon() {
                                            if (!wifiConnected) return "󰤭"
                                            return "󰤨"
                                        }
                                    }
                                    
                                    Text {
                                        text: wifiConnected ? wifiSsid : "Disconnected"
                                        color: Theme.textSecondary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                        width: Math.min(implicitWidth, 80)
                                    }
                                }
                                
                                MouseArea {
                                    id: wifiMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onClicked: root.wifiPopupVisible = !root.wifiPopupVisible
                                }
                                
                                Behavior on color {
                                    ColorAnimation { duration: Theme.animationFast }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ========================================================================
    // AUDIO POPUP
    // ========================================================================
    
    PopupWindow {
        id: audioPopup
        
        visible: root.audioPopupVisible && root.panelWindowRef !== null
        
        anchor {
            window: root.panelWindowRef
            rect: root.audioIndicatorRef ? 
                Qt.rect(
                    root.audioIndicatorRef.mapToItem(null, 0, 0).x,
                    root.audioIndicatorRef.mapToItem(null, 0, 0).y,
                    root.audioIndicatorRef.width,
                    root.audioIndicatorRef.height
                ) : Qt.rect(0, 0, 0, 0)
            edges: Edges.Bottom
        }
        
        implicitWidth: 280
        implicitHeight: 120
        color: "transparent"
        
        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.spacingSmall
            
            radius: Theme.radiusLarge
            color: Theme.withAlpha(Theme.bgSurface, 0.95)
            border.width: 1
            border.color: Theme.withAlpha(Theme.bgBorder, 0.5)
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: {
                    if (!containsMouse) root.audioPopupVisible = false
                }
            }
            
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
                        color: muteBtnArea.containsMouse ? Theme.bgActive : Theme.bgHover
                        
                        Text {
                            anchors.centerIn: parent
                            text: muted ? "󰝟" : "󰕾"
                            color: muted ? Theme.accentRed : Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.iconSizeMedium
                        }
                        
                        MouseArea {
                            id: muteBtnArea
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
                    
                    Text {
                        text: "󰕿"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.iconSizeSmall
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        height: 8
                        radius: 4
                        color: Theme.bgHover
                        
                        Rectangle {
                            width: parent.width * volume
                            height: parent.height
                            radius: parent.radius
                            color: muted ? Theme.audioMuted : Theme.accentBlue
                            
                            Behavior on width {
                                NumberAnimation { duration: Theme.animationFast; easing.type: Easing.OutCubic }
                            }
                        }
                        
                        Rectangle {
                            x: parent.width * volume - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            radius: 8
                            color: Theme.textPrimary
                            
                            Behavior on x {
                                NumberAnimation { duration: Theme.animationFast; easing.type: Easing.OutCubic }
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            function updateVolume(mx) {
                                volume = Math.max(0, Math.min(1, mx / width))
                            }
                            onPressed: updateVolume(mouseX)
                            onPositionChanged: { if (pressed) updateVolume(mouseX) }
                        }
                    }
                    
                    Text {
                        text: "󰕾"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.iconSizeSmall
                    }
                    
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
            }
        }
    }
    
    // ========================================================================
    // WIFI POPUP
    // ========================================================================
    
    PopupWindow {
        id: wifiPopup
        
        visible: root.wifiPopupVisible && root.panelWindowRef !== null
        
        anchor {
            window: root.panelWindowRef
            rect: root.wifiIndicatorRef ? 
                Qt.rect(
                    root.wifiIndicatorRef.mapToItem(null, 0, 0).x,
                    root.wifiIndicatorRef.mapToItem(null, 0, 0).y,
                    root.wifiIndicatorRef.width,
                    root.wifiIndicatorRef.height
                ) : Qt.rect(0, 0, 0, 0)
            edges: Edges.Bottom
        }
        
        implicitWidth: 320
        implicitHeight: Math.min(400, networkColumn.height + Theme.spacingLarge * 2)
        color: "transparent"
        
        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.spacingSmall
            
            radius: Theme.radiusLarge
            color: Theme.withAlpha(Theme.bgSurface, 0.95)
            border.width: 1
            border.color: Theme.withAlpha(Theme.bgBorder, 0.5)
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: {
                    if (!containsMouse) root.wifiPopupVisible = false
                }
            }
            
            ColumnLayout {
                id: networkColumn
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
                        color: refreshBtnArea.containsMouse ? Theme.bgActive : Theme.bgHover
                        
                        Text {
                            id: refreshIcon
                            anchors.centerIn: parent
                            text: "󰑐"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.iconSizeMedium
                            
                            property bool spinning: root.wifiDevice?.scannerEnabled ?? false
                            
                            RotationAnimation on rotation {
                                running: refreshIcon.spinning
                                from: 0
                                to: 360
                                duration: 1000
                                loops: Animation.Infinite
                            }
                            
                            onSpinningChanged: { if (!spinning) rotation = 0 }
                        }
                        
                        MouseArea {
                            id: refreshBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (root.wifiDevice) root.wifiDevice.scannerEnabled = true }
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
                    }
                }
                
                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.bgBorder
                    visible: wifiConnected
                }
                
                // Available networks label
                Text {
                    text: "Available Networks"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    visible: root.availableNetworks.length > 0
                }
                
                // Network list
                Column {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Theme.spacingSmall
                    
                    Repeater {
                        model: root.availableNetworks
                        
                        Rectangle {
                            width: parent.width
                            height: 44
                            radius: Theme.radiusMedium
                            color: netArea.containsMouse ? Theme.bgActive : Theme.bgHover
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingMedium
                                spacing: Theme.spacingMedium
                                
                                Text {
                                    text: modelData.secure ? "󰌾" : "󰤪"
                                    color: modelData.secure ? Theme.textSecondary : Theme.accentOrange
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.iconSizeSmall
                                }
                                
                                Text {
                                    text: modelData.ssid
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeMedium
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                
                                Text {
                                    text: getSignalIcon(modelData.signal)
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.iconSizeMedium
                                    
                                    function getSignalIcon(s) {
                                        if (s > 80) return "󰤨"
                                        if (s > 60) return "󰤥"
                                        if (s > 40) return "󰤢"
                                        if (s > 20) return "󰤟"
                                        return "󰤯"
                                    }
                                }
                            }
                            
                            MouseArea {
                                id: netArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: console.log("Connect to:", modelData.ssid)
                            }
                        }
                    }
                }
                
                // Empty state
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: (root.wifiDevice?.scannerEnabled ?? false) ? "Scanning..." : "No networks found"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    visible: root.availableNetworks.length === 0
                }
            }
        }
    }
}
