{ config, pkgs, ... }:

{
  home.packages = [
    (pkgs.discord.override {
      # Discord has a min width of 940px. On the laptop (eDP-1, scale 2) each
      # tiled half is 724 logical px wide. Scale factor = 940/724 ≈ 1.298 so
      # the app fits without exceeding the available width.
      commandLineArgs = "--force-device-scale-factor=0.702";
    })
  ];
}
