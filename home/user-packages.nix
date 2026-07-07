{ pkgs, ... }:

{
  home.packages = with pkgs; [
    kdePackages.kate
    gimp
    obsidian
    kubectl
    virt-manager
    kubernetes-helm
    ripgrep
    bruno
    claude-code
    dbeaver-bin
  ];
}
