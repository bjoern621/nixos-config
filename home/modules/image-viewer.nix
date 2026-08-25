{ pkgs, ... }:

let
  # imv handles all common raster formats plus SVG via librsvg.
  imageMimeTypes = [
    "image/png"
    "image/jpeg"
    "image/webp"
    "image/svg+xml"
    "image/gif"
    "image/bmp"
    "image/tiff"
    "image/avif"
    "image/heif"
  ];
in
{
  home.packages = with pkgs; [
    imv
  ];

  # Checkerboard behind transparency.
  # Default black background hides dark line art (transparent SVGs).
  xdg.configFile."imv/config".text = ''
    [options]
    background = checks
  '';

  xdg.mimeApps = {
    enable = true;
    defaultApplications = builtins.listToAttrs (
      map (mime: {
        name = mime;
        value = "imv.desktop";
      }) imageMimeTypes
    );
  };

  wayland.windowManager.hyprland.extraLuaFiles."rules.32-image-viewer".content = ./image-viewer.lua;
}
