{ pkgs, ... }:

{
  fonts = {
    fontDir.enable = true;

    packages = with pkgs; [
      inter
      noto-fonts
      jetbrains-mono
    ];

    fontconfig = {
      enable = true;

      defaultFonts = {
        serif = [ "Noto Serif" ];
        sansSerif = [ "Inter" ];
        monospace = [ "JetBrains Mono" ];
        emoji = [ "Noto Color Emoji" ];
      };

      antialias = true;
      hinting = {
        enable = true;
        style = "full";
      };

      subpixel = {
        rgba = "rgb";
        lcdfilter = "light";
      };
    };
  };

  # Enable advanced FreeType subpixel hinting (better than standard hinting)
  # This uses the "ClearType" style rendering from Microsoft
  environment.variables.FREETYPE_PROPERTIES = "truetype:interpreter-version=35 cff:no-stem-darkening=1 autofitter:warping=1";
}
