{ config, pkgs, ... }:

{
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        padding = {
          x = 8;
          y = 8;
        };
        decorations = "None";
      };
    };
    theme = "monokai_pro";
  };
}
