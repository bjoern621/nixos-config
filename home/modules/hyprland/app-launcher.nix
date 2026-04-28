{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER, Super_L, global, quickshell:launcher"
    ];

    layerrule = [
      "blur on, match:namespace quickshell-launcher"
      "ignore_alpha 0.01, match:namespace quickshell-launcher"
      "no_anim on, match:namespace quickshell-launcher"
    ];
  };
}
