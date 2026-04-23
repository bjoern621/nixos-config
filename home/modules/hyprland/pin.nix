{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER, P, pin,"
    ];

    windowrule = [
      "border_color rgb(ffffff), match:pin true"
    ];
  };
}
