{ ... }:

{
  # Mozza Mail dev window: pin to workspace 5 at a specific size/position
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "workspace 5 silent, match:class (electron)"
      "float on, match:class (electron)"
      "size (monitor_w*0.85) (monitor_h*0.85), match:class (electron)"
      "move (monitor_w*0.076) (monitor_h*0.076), match:class (electron)"
    ];
  };
}
