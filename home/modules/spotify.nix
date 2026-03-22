{ config, pkgs, ... }:

{
  home.packages = [
    # Spotify has a min width of 800px. On the laptop (eDP-1, scale 2) each
    # tiled half is 724 logical px wide. Scale 0.905 * 800 = 724,
    # so Spotify fits side-by-side with Discord.
    (pkgs.spotify.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        wrapProgram $out/bin/spotify \
          --add-flags "--force-device-scale-factor=0.905"
      '';
    }))
  ];
}
