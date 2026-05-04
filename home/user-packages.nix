{ pkgs, ... }:

{
  home.packages = with pkgs; [
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
    mkchromecast
  ];
}
