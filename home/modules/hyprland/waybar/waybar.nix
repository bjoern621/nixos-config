{ pkgs, ... }:

let
  powerMenu = pkgs.writeShellScriptBin "power-menu" (builtins.readFile ./power-menu.sh);
in
{
  programs.waybar = {
    enable = true;
    style = builtins.readFile ./waybar.css;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";

        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [ "tray" "battery" "pulseaudio" "network" "custom/powermenu" ];

        "clock" = {
          format = " {:L%I:%M %p}";
        };

        "battery" = {
          format = "{capacity}% {icon}";
          format-icons = ["" "" "" "" ""];
        };
        
        "pulseaudio" = {
          format = "{volume}% {icon}";
          format-icons = {
            default = ["" "" ""];
          };
          on-click = "pavucontrol";
        };

        "network" = {
          format-wifi = " ";
          format-ethernet = "󰈀 ";
          format-disconnected = "󰖪";
          on-click = "nm-connection-editor";
        };

        "custom/powermenu" = {
          exec = "echo '⏻'";
          format = "{output}";
          on-click = "${powerMenu}/bin/power-menu";
        };
      };
    };
  };

  wayland.windowManager.hyprland.settings.exec-once = [ "waybar" ];
}
