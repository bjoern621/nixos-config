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
      "match:class google-chrome, workspace 1"
      "match:class code, workspace 2"
      "match:class spotify, workspace 3"
      "match:class discord, workspace 3"
    ];
  };
}
