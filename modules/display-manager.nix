{ ... }:

{
  services.displayManager.enabled = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
}
