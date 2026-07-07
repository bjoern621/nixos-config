{ pkgs, ... }:

{
  # See also: https://wiki.hypr.land/Useful-Utilities/Clipboard-Managers/

  home.packages = with pkgs; [
    cliphist
    wl-clipboard
    wtype
  ];

  # Watch for new clipboard content and store it in the history.
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "wl-paste -t text --watch cliphist -max-items 100 store"
      "wl-paste -t image --watch cliphist -max-items 100 store"
    ];

    # Routed via Hyprland's `global` dispatcher to the running quickshell.
    # ~125ms faster than `qs ipc call` (cold-start avoidance).
    # Selecting an entry copies it to the clipboard and pastes via Ctrl+Shift+V.
    bind = [
      "SUPER, V, exec, hyprctl dispatch global quickshell:clipboard"
    ];

    layerrule = [
      "blur on, match:namespace quickshell-clipboard"
      "ignore_alpha 0.01, match:namespace quickshell-clipboard"
      "no_anim on, match:namespace quickshell-clipboard"
    ];
  };
}
