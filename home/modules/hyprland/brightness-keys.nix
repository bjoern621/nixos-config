{ pkgs, ... }:

{
  wayland.windowManager.hyprland.settings = {
    bind = [
      ", XF86MonBrightnessUp, exec, brightnessctl set +10%"
      ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"
    ];
  };
}
