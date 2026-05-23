{ ... }:

{
  # Mozza Mail dev window: pin to workspace 5 at a specific size/position
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "workspace 5 silent, match:class (electron)"
      "float on, match:class (electron)"
      "size 2173 1222, match:class (electron)"
      "move 194 109, match:class (electron)"
    ];
  };
}
