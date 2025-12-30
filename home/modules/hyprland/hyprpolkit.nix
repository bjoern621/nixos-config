{ pkgs, ... }:

{
    # https://wiki.hypr.land/Hypr-Ecosystem/hyprpolkitagent/
    
    wayland.windowManager.hyprland.settings.exec-once = [
      "systemctl --user start hyprpolkitagent"
    ];

    home.packages = [
      pkgs.hyprpolkitagent
    ];
}