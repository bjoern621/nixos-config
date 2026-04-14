{ pkgs, ... }:

{
  home.packages = with pkgs; [
    firefox
    kdePackages.kate
    gimp
    obsidian
    element-desktop
    direnv
    kubectl
    virt-manager
    kubernetes-helm
    ripgrep
    bruno
  ];
}
