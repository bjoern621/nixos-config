-- Cursor variables:
-- - XCURSOR_* is the standard Xcursor interface (XWayland and many toolkits).
-- - HYPRCURSOR_* is Hyprland's cursor backend (Hyprland-native cursor handling).
-- Setting both keeps cursor theme consistent across Wayland-native and XWayland apps.
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice") -- https://www.gnome-look.org/p/1197198
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
