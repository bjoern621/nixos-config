{ config, pkgs, ... }:

{
  home.packages = [
    # Spotify has a min width of 800px. On the laptop (eDP-1, scale 2) each
    # tiled half is 724 logical px wide. Scale factor = 800/724 ≈ 1.105 so
    # the app fits without exceeding the available width.
    (pkgs.spotify.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        wrapProgram $out/bin/spotify \
          --add-flags "--force-device-scale-factor=1.105"
      '';
    }))
  ];
}
