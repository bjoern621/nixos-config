{ ... }:

{
  # Emoji picker (Super+.) shown by quickshell.
  # Routed via Hyprland's `global` dispatcher to the running quickshell.
  # Selecting an emoji copies it to the clipboard and pastes via Ctrl+Shift+V.
  wayland.windowManager.hyprland.settings = {
    bind = [
      "SUPER, period, exec, hyprctl dispatch global quickshell:emoji"
    ];

    layerrule = [
      "blur on, match:namespace quickshell-emoji"
      "ignore_alpha 0.01, match:namespace quickshell-emoji"
      "no_anim on, match:namespace quickshell-emoji"
    ];
  };
}
