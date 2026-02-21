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
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
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
    
    // ========================================================================
    // GLOBAL STATE
    // ========================================================================
    
    // Audio state
    property real volume: Pipewire.defaultAudioSink?.audio?.volume ?? 0.5
    property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false
    
    // Network state - using native Quickshell.Networking API
    property var wifiDevice: {
        const devices = Networking.devices.values;
        for (const dev of devices) {
            if (dev.type === DeviceType.Wifi) return dev;
        }
        return null;
    }
    property string wifiSsid: wifiDevice?.activeConnection?.ssid ?? ""
    property bool wifiConnected: wifiDevice?.state === DeviceConnectionState.Connected
    property var wifiNetworks: wifiDevice?.networks.values ?? []
    
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
