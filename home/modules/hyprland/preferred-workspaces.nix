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
      "workspace 1,class:google-chrome"
      "workspace 2,class:code"
      "workspace 3,class:spotify"
      "workspace 3,class:discord"
      "float,class:mpv"
    ];

    workspace = [
      "1, monitor:desc:LG Electronics LG ULTRAGEAR 308MAPN9YD64, default:true, persistent:true"
      "2, monitor:desc:LG Electronics LG ULTRAGEAR 308MAVD9YD63, default:true, persistent:true"
      "3, persistent:true"
    ];
  };
}
