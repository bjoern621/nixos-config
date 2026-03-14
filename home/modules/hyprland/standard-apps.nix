{ pkgs, ... }:

{
  # Gtk3 is needed for gtk-launch, which is used to run desktop files..
  home.packages = [ pkgs.gtk3 ];

  wayland.windowManager.hyprland.settings.exec-once = [
    "[workspace 1 silent] gtk-launch google-chrome"
    "[workspace 2 silent] gtk-launch code"
  ];
}
