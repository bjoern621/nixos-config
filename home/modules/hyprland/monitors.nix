{ ... }:

{
  # sysconf-fix-monitors hardcodes the monitor strings from monitors.lua.
  # Keep both in sync.
  wayland.windowManager.hyprland.extraLuaFiles."monitors".content = ./monitors.lua;
}
