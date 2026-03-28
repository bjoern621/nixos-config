{ pkgs, ... }:

{
  home.packages = with pkgs; [
    qimgv
  ];

  xdg.configFile."qimgv/qimgv.conf" = {
    force = true;
    text = ''
      [General]
      infoBarWindowed=true
    '';
  };

  wayland.windowManager.hyprland.settings.windowrule = [
    "float on, match:class qimgv"
  ];
}
