// ============================================================================
// Dynamic Island Shell - Main Entry Point
// A modern, playful status bar inspired by Apple's Dynamic Island
// ============================================================================

//@ pragma UseQApplication
//@ pragma Env QT_QPA_PLATFORMTHEME=gtk3
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Services.Network
import QtQuick
import "components" as Components

ShellRoot {
    id: root
    
    // ========================================================================
    // GLOBAL SERVICES
    // ========================================================================
    
    // System clock for time/date
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    
    // System tray
    SystemTray {
        id: systemTray
    }
    
    // Network service
    NetworkService {
        id: networkService
    }
    
    // Track default audio sink for volume control
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
    
    // ========================================================================
    // GLOBAL STATE
    // ========================================================================
    
    // Audio state
    property real volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0.5
    property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false
    
    // Network state
    property string wifiSsid: ""
    property bool wifiConnected: false
    property var wifiNetworks: []
    
    // Active MPRIS player
    property var activePlayer: {
        const players = Mpris.players.values;
        if (!players || players.length === 0) return null;
        for (const p of players) {
            if (p.playbackState === MprisPlaybackState.Playing) return p;
        }
        return players[0];
    }
    
    // ========================================================================
    // NETWORK MONITORING
    // ========================================================================
    
    Process {
        id: wifiScanner
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]
        running: true
        
        stdout: SplitParser {
            onRead: data => {
                const lines = data.trim().split("\n");
                const networks = [];
                let currentSsid = "";
                
                for (const line of lines) {
                    const parts = line.split(":");
                    if (parts.length >= 4) {
                        const isActive = parts[0] === "yes";
                        const ssid = parts[1];
                        const signal = parseInt(parts[2]) || 0;
                        const security = parts[3] || "";
                        
                        if (ssid && ssid !== "--") {
                            networks.push({
                                ssid: ssid,
                                signal: signal,
                                security: security,
                                connected: isActive
                            });
                            
                            if (isActive) {
                                currentSsid = ssid;
                            }
                        }
                    }
                }
                
                root.wifiNetworks = networks;
                root.wifiSsid = currentSsid;
                root.wifiConnected = currentSsid !== "";
            }
        }
        
        // Rescan every 10 seconds
        Timer {
            running: true
            interval: 10000
            repeat: true
            onTriggered: wifiScanner.running = true
        }
    }
    
    // ========================================================================
    // IPC HANDLERS
    // ========================================================================
    
    IpcHandler {
        target: "island"
        
        function toggleAudio(): void {
            islandBar.audioPopupVisible = !islandBar.audioPopupVisible;
        }
        
        function toggleWifi(): void {
            islandBar.wifiPopupVisible = !islandBar.wifiPopupVisible;
        }
        
        function closeAll(): void {
            islandBar.audioPopupVisible = false;
            islandBar.wifiPopupVisible = false;
        }
    }
    
    // ========================================================================
    // COMPONENTS
    // ========================================================================
    
    // Main Dynamic Island Bar (includes popups)
    Components.IslandBar {
        id: islandBar
    }
}
