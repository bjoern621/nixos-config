{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    input = {
      accel_profile = "flat"; # Disable mouse acceleration globally
    };

    # Keep acceleration enabled for touchpad
    # https://wiki.hypr.land/Configuring/Keywords/#per-device-input-configs
    "device[syna2ba6:00-06cb:cf00-touchpad]" = {
      accel_profile = "adaptive";
    };
  };
}
