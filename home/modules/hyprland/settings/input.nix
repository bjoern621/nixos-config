{ ... }:

{
  # https://wiki.hypr.land/Configuring/Variables/#input
  wayland.windowManager.hyprland.settings.input = {
    kb_layout = "de";

    touchpad = {
      natural_scroll = true; # true: Swipe down -> content moves down
      scroll_factor = 1.0;
    };
  };
}
