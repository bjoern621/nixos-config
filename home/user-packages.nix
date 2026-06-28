{ pkgs, ... }:

{
  home.packages = with pkgs; [
    kdePackages.kate
    gimp
    obsidian
    element-desktop
    kubectl
    virt-manager
    kubernetes-helm
    ripgrep
    bruno
    mkchromecast
    claude-code
    dbeaver-bin
  ];
}
