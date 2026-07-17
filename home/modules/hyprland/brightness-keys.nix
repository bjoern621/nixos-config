{ pkgs, ... }:

{
  wayland.windowManager.hyprland.settings = {
    # Only these keys change brightness, and brightnessctl emits no change event.
    # Notify is load-bearing: without it the OSD must poll. See osd/BrightnessOsd.qml.
    #
    # `hyprctl dispatch global` reaches the resident quickshell.
    # `qs ipc call brightness show` cold-starts a Qt binary per keypress (~125ms),
    # and the OSD waits behind it.
    # `global` from a bind never reaches the client, so it goes through exec.
    # Same workaround as app-launcher.nix.
    bind = [
      ", XF86MonBrightnessUp, exec, brightnessctl set +10% && hyprctl dispatch global quickshell:brightness"
      ", XF86MonBrightnessDown, exec, brightnessctl set 10%- && hyprctl dispatch global quickshell:brightness"
    ];
  };
}
