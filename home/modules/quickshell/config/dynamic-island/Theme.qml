// ============================================================================
// Dynamic Island Theme - Modern, Playful Design System
// Inspired by Apple's Dynamic Island with a cohesive dark aesthetic
// ============================================================================

pragma Singleton
import QtQuick

QtObject {
    // ========================================================================
    // COLOR PALETTE
    // ========================================================================
    
    // Base colors - Deep dark with subtle warmth
    readonly property color bgBase: "#0a0a0c"           // Deepest black
    readonly property color bgSurface: "#161618"        // Card backgrounds
    readonly property color bgElevated: "#1c1c1f"       // Elevated surfaces
    readonly property color bgHover: "#252528"          // Hover states
    readonly property color bgActive: "#2d2d31"         // Active/pressed states
    readonly property color bgBorder: "#3a3a3f"         // Subtle borders
    readonly property color bgGlow: "#404045"           // Glow effects
    
    // Text colors
    readonly property color textPrimary: "#ffffff"      // Primary text
    readonly property color textSecondary: "#a1a1aa"    // Secondary text
    readonly property color textMuted: "#71717a"        // Muted/disabled text
    readonly property color textAccent: "#f4f4f5"       // Highlighted text
    
    // Accent colors - Vibrant but not oversaturated
    readonly property color accentBlue: "#3b82f6"       // Primary accent
    readonly property color accentBlueLight: "#60a5fa"  // Lighter variant
    readonly property color accentBlueDark: "#2563eb"   // Darker variant
    readonly property color accentPurple: "#a855f7"     // Secondary accent
    readonly property color accentPink: "#ec4899"       // Tertiary accent
    readonly property color accentGreen: "#22c55e"      // Success/positive
    readonly property color accentYellow: "#eab308"     // Warning
    readonly property color accentOrange: "#f97316"     // Attention
    readonly property color accentRed: "#ef4444"        // Error/critical
    
    // Semantic colors
    readonly property color wifiConnected: accentBlue
    readonly property color wifiDisconnected: textMuted
    readonly property color audioHigh: accentBlue
    readonly property color audioMedium: accentBlueLight
    readonly property color audioLow: textSecondary
    readonly property color audioMuted: accentRed
    readonly property color workspaceActive: accentBlue
    readonly property color workspaceInactive: bgSurface
    readonly property color workspaceUrgent: accentRed
    
    // ========================================================================
    // TYPOGRAPHY
    // ========================================================================
    
    readonly property string fontFamily: "JetBrains Mono"  // Monospace for tech feel
    readonly property string fontFamilyAlt: "Inter"        // Alternative for UI
    
    readonly property int fontSizeTiny: 10
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeMedium: 12
    readonly property int fontSizeLarge: 14
    readonly property int fontSizeXLarge: 16
    readonly property int fontSizeXXLarge: 20
    
    readonly property int fontWeightNormal: 400
    readonly property int fontWeightMedium: 500
    readonly property int fontWeightBold: 600
    
    // ========================================================================
    // SPACING & SIZING
    // ========================================================================
    
    readonly property int spacingTiny: 2
    readonly property int spacingSmall: 4
    readonly property int spacingMedium: 8
    readonly property int spacingLarge: 12
    readonly property int spacingXLarge: 16
    readonly property int spacingXXLarge: 24
    
    // Island dimensions
    readonly property int islandHeight: 36
    readonly property int islandRadius: 18
    readonly property int islandRadiusExpanded: 24
    readonly property int islandPadding: spacingMedium
    
    // Component sizes
    readonly property int iconSizeSmall: 12
    readonly property int iconSizeMedium: 14
    readonly property int iconSizeLarge: 16
    readonly property int iconSizeXLarge: 20
    
    readonly property int pillHeight: 28
    readonly property int pillRadius: 14
    
    // ========================================================================
    // ANIMATION
    // ========================================================================
    
    readonly property int animationFast: 150
    readonly property int animationMedium: 250
    readonly property int animationSlow: 400
    
    // Easing curves
    readonly property var easeOutCubic: [0.33, 0.0, 0.0, 1.0]
    readonly property var easeInOutCubic: [0.65, 0.0, 0.35, 1.0]
    readonly property var easeOutBack: [0.34, 1.56, 0.64, 1.0]
    
    // ========================================================================
    // EFFECTS
    // ========================================================================
    
    readonly property real shadowOpacity: 0.3
    readonly property real glowOpacity: 0.15
    readonly property real blurRadius: 20
    
    // ========================================================================
    // HELPER FUNCTIONS
    // ========================================================================
    
    function withAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }
    
    function mix(color1, color2, ratio) {
        return Qt.rgba(
            color1.r + (color2.r - color1.r) * ratio,
            color1.g + (color2.g - color1.g) * ratio,
            color1.b + (color2.b - color1.b) * ratio,
            color1.a + (color2.a - color1.a) * ratio
        )
    }
}
