{ ... }:

{
  # https://wiki.hypr.land/Configuring/Variables/#misc
  wayland.windowManager.hyprland.settings.misc = {
    # Variable Frame Rate, reduces rendering when idle for power saving
    vfr = true;
    # Variable Refresh Rate
    vrr = 1;
    # Disable Hyprland's automatic config reload on file changes, since we use sysconf-reload anyway
    disable_autoreload = true;
  };
}
