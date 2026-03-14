{ pkgs, ... }:

{
  home.packages = [ pkgs.gtk3 ];

  wayland.windowManager.hyprland.settings.exec-once = [
    "[workspace 1 silent] google-chrome"
    "[workspace 2 silent] code --password-store=\"gnome-libsecret\" --touch-events"
  ];
}
