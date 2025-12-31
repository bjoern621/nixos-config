## Assigns specific applications to preferred workspaces in Hyprland.
#
# This module sets Hyprland window rules so that:
# - Google Chrome always opens on workspace 1
# - Visual Studio Code always opens on workspace 2
#
# The class names must match the actual application window class (use `hyprctl clients` to check).
{
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "match:class google-chrome, rounding 1"
      "match:class code, rounding 2"
      "match:class spotify, rounding 3"
      "match:class discord, rounding 3"
    ];

    workspace = [
      "1, monitor:desc:LG Electronics LG ULTRAGEAR 308MAPN9YD64, default:true, persistent:true"
      "2, monitor:desc:LG Electronics LG ULTRAGEAR 308MAVD9YD63, default:true, persistent:true"
      "3, persistent:true"
    ];
  };
}
