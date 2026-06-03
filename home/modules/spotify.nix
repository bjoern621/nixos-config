{ config, pkgs, ... }:

{
  home.packages = [
    # Spotify has a min width of 800px. On the laptop (eDP-1, scale 2) each
    # tiled half is 724 logical px wide. Scale 0.905 * 800 = 724,
    # so Spotify fits side-by-side with Discord.
    #
    # Version pin: Spotify 1.2.86 (Chrome/144 CEF) renders blurry text under
    # XWayland at scale 2. 1.2.84 is the last crisp release. Pin src/version
    # here so `sysconf-update` can't pull 1.2.86 back in. Remove the pin once a
    # later upstream release renders crisply again.
    (pkgs.spotify.overrideAttrs (old: {
      version = "1.2.84.475.ga1a748ff";
      src = pkgs.fetchurl {
        url = "https://api.snapcraft.io/api/v1/snaps/download/pOBIoZ2LrCB3rDohMxoYGnbN14EHOgD7_93.snap";
        sha512 = "5fd22c95787530713126906ee399979c8a307619af901928f9fba9936dd684a36850f491dfb8db8f911ee15d9960ac42b60c83817f0fc7560aca7bb728455416";
      };
      postInstall = (old.postInstall or "") + ''
        wrapProgram $out/bin/spotify \
          --add-flags "--force-device-scale-factor=0.905"
      '';
    }))
  ];
}
