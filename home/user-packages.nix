{ pkgs, ... }:

{
  home.packages = with pkgs; [
    kdePackages.kate # text editor
    gimp
    obsidian
    kubectl # Kubernetes CLI
    virt-manager # libvirt VM GUI, e.g. homelab host VM management
    kubernetes-helm # helm cmd (Kubernetes package manager)
    ripgrep # rg cmd (fast grep)
    bruno # API client
    dbeaver-bin # SQL database GUI
    dnsutils # dig, nslookup, host
    wdisplays # Wayland display layout GUI
    wlr-randr # xrandr (X11 Resize and Rotate) for wlroots (wayland roots) compositors
    usbutils # lsusb
    brightnessctl # backlight control (used by Hyprland brightness keys)
    tldr # tldr cmd (summary pages)
    k9s
  ];
}
