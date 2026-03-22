{ config, pkgs, ... }:

{
  home.packages = [
    (pkgs.discord.override {
      # Discord has a min width of 940px. On the laptop (eDP-1, scale 2) each
      # tiled half is 724 logical px wide. Scale 0.77 * 940 = 724,
      # so Discord fits side-by-side with Spotify.
      commandLineArgs = "--force-device-scale-factor=0.77";
    })
  ];
}
