{
  programs.waybar = {
    enable = true;
    style = builtins.readFile ./waybar.css;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        modules-left = [ "hyprland/workspaces" "clock" ];
        modules-center = [ ];
        modules-right = [ "tray" "battery" ];
        "clock" = {
          format = "{:%H:%M}";
        };
        "battery" = {
          format = "{capacity}% {icon}";
        };
      };
    };
  };
}
