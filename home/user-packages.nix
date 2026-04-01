{ pkgs, ... }:

{
  home.packages = with pkgs; [
    firefox
    kdePackages.kate
    gimp
    obsidian
    element-desktop
  ];
}
