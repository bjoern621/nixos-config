{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    # Workaround: `bind = SUPER, Super_L, global, quickshell:launcher` registers
    # in Hyprland and fires reliably, but the `global` dispatcher invoked from a
    # keybind does not reach the quickshell client (while `hyprctl dispatch
    # global ...` does). Routing through `exec hyprctl dispatch` works.
    bind = [
      "SUPER, Super_L, exec, hyprctl dispatch global quickshell:launcher"
    ];

    layerrule = [
      "blur on, match:namespace quickshell-launcher"
      "ignore_alpha 0.01, match:namespace quickshell-launcher"
      "no_anim on, match:namespace quickshell-launcher"
    ];
  };
}
