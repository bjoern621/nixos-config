{
  inputs,
  pkgs,
  config,
  customLib,
  ...
}:

let
  qs = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Python with added keyring and secretstorage packages for Spotify API integration.
  qsPython = pkgs.python3.withPackages (ps: [
    ps.keyring
    ps.secretstorage
  ]);

  # Private runtime deps — visible only to the quickshell process and its
  # children, never added to the user's global environment.
  qsWrapped = customLib.wrapWithPrivateDeps qs {
    bin = "quickshell";
    binDeps = [
      pkgs.imagemagick # WallpaperAccent color extraction
      pkgs.libnotify # notify-send for desktop notifications
      qsPython
    ];
    dataDeps = [
      pkgs.inter # Text
    ];
  };

  # CLI helper for one-time user setup (setup/auth/clear).
  # This gives the user a python executable that also has keyring+secretstorage available.
  spotifyCli = pkgs.writeShellScriptBin "quickshell-spotify" ''
    exec ${qsPython}/bin/python3 "$HOME/.config/quickshell/spotify_api.py" "$@"
  '';
in

{
  # User-level quickshell configuration.
  # NOTE: This module is paired with modules/quickshell.nix
  # which contains system-level dependencies like UPower.

  home.packages = with pkgs; [
    qsWrapped # quickshell + private PATH/fonts (imagemagick, python3+keyring, font-awesome, inter)
    spotifyCli # quickshell-spotify: user-facing CLI for setup/auth/clear
    # inputs.caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # Link quickshell config to ~/.config/quickshell via an out-of-store symlink
  # so that Quickshell's hot reload can detect file changes directly in the repo.
  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/git/nixos-config/home/modules/quickshell/config/dynamic-island";

  # Autostart quickshell as a systemd user service (UWSM-managed session)
  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${qsWrapped}/bin/quickshell";
      Restart = "on-failure";
      RestartSec = 1;
      # Without a platform theme, Qt defaults to hicolor icons.
      # gtk3 makes Qt read the icon theme from GTK settings (gtk.iconTheme).
      Environment = [ "QT_QPA_PLATFORMTHEME=gtk3" ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Hyprland layerrule for quickshell blur effect.
  # ignore_alpha 0.1 skips blur on pixels with alpha <= 0.1, so the transparent
  # PanelWindow background is not blurred, only the pill (alpha 0.7, at the time of writing) is.
  # When the pill is slid off-screen it is clipped, leaving only the transparent
  # background, so blur disappears without any extra logic.
  wayland.windowManager.hyprland.settings.layerrule = [
    "blur on, match:namespace quickshell"
    "ignore_alpha 0.01, match:namespace quickshell"
  ];
}
