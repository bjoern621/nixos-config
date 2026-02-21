{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    rofi
  ];

  # SUPER key alone opens/closes rofi (bindr = bind on key release)
  # Uses 'uwsm app --' to launch apps in their own systemd units (app-graphical.slice)
  # instead of inside the compositor's unit. This provides proper resource management
  # and clean session handling.
  # See: https://github.com/Vladimir-csp/uwsm#3-applications-and-slices
  wayland.windowManager.hyprland.settings.bindr = [
    "SUPER, Super_L, exec, pkill rofi || rofi -show drun -show-icons -run-command 'uwsm app -- {cmd}'"
  ];
}
