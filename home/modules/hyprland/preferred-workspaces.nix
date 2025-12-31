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
      "workspace 1, match:match class google-chrome"
      "workspace 2, match:match class code"
      "workspace 3, match:match class spotify"
      "workspace 3, match:match class discord"
    ];
  };
}
