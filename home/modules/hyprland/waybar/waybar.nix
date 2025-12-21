{
  programs.waybar = {
    enable = true;
    style = builtins.readFile ./waybar.css;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "custom/date" "clock" ];
        modules-right = [ "tray" "battery" "custom/powermenu" ];

        "clock" = {
          format = "{:%H:%M}";
        };

        "custom/date" = {
          exec = "date '+%a %d %b %Y'";
          interval = 60;
          format = "{output}";
        };

        "battery" = {
          format = "{capacity}% {icon}";
        };
        
        "custom/powermenu" = {
          exec = "echo '⏻'";
          format = "{output}";
          on-click = "bash -c '$HOME/.config/waybar/power-menu.sh'";
        };
      };
    };
  };

  wayland.windowManager.hyprland.settings.exec-once = [ "waybar" ];
}
