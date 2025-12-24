## Assigns specific applications to preferred workspaces in Hyprland.
#
# This module sets Hyprland window rules so that:
# - Google Chrome always opens on workspace 1
# - Visual Studio Code always opens on workspace 2
#
# The class names must match the actual application window class (use `hyprctl clients` to check).
{
  wayland.windowManager.hyprland.settings = {
    windowrulev2 = [
      "workspace 1, class:^(Google-chrome)$"
      "workspace 2, class:^(code)$"
    ];
  };
}
