{ ... }:

{
  # https://wiki.hypr.land/Configuring/Variables/#general
  wayland.windowManager.hyprland.settings.general = {
    border_size = 1;
    gaps_out = "8,8,8,8";
    gaps_in = 2;
    "col.active_border" = "rgba(255,255,255,0.2)"; # "col.active_border" (with dot) so that Nix does not convert it to a subcategory
    "col.inactive_border" = "rgba(255,255,255,0)";
    resize_on_border = true;
  };
}
