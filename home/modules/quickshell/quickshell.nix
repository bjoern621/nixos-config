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

  # Session-lock launcher. Runs the lock config as a separate Quickshell process
  # (config/lock), kept apart from the bar instance so a bar reload or crash
  # cannot affect the lock and vice versa. Single-instance: a second invocation
  # while a lock is already up is a no-op, so repeated lock-session signals do
  # not stack surfaces.
  quickshellLock = pkgs.writeShellScriptBin "quickshell-lock" ''
    if ${pkgs.procps}/bin/pgrep -f 'quickshell.*quickshell-lock/shell.qml' >/dev/null 2>&1; then
      exit 0
    fi
    exec ${qsWrapped}/bin/quickshell -p "$HOME/.config/quickshell-lock/shell.qml"
  '';

  # Emoji dataset for the EmojiPicker (Super+.). Built from Unicode's
  # emoji-test.txt + CLDR annotations (en + de) at home-manager rebuild,
  # so updating nixpkgs auto-bumps the dataset.
  emojiData = pkgs.runCommand "quickshell-emoji-data.json" {
    nativeBuildInputs = [ pkgs.python3 ];
  } ''
    python3 ${./gen-emoji.py} \
      ${pkgs.unicode-emoji}/share/unicode/emoji/emoji-test.txt \
      ${pkgs.cldr-annotations}/share/unicode/cldr/common/annotations/en.xml \
      ${pkgs.cldr-annotations}/share/unicode/cldr/common/annotations/de.xml \
      > $out
  '';
in

{
  # User-level quickshell configuration.
  # NOTE: This module is paired with modules/quickshell.nix
  # which contains system-level dependencies like UPower.

  home.packages = with pkgs; [
    qsWrapped # quickshell + private PATH/fonts (imagemagick, python3+keyring, font-awesome, inter)
    spotifyCli # quickshell-spotify: user-facing CLI for setup/auth/clear
    quickshellLock # quickshell-lock: launches the session lock (config/lock)
  ];

  # Link quickshell config to ~/.config/quickshell via an out-of-store symlink
  # so that Quickshell's hot reload can detect file changes directly in the repo.
  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/git/nixos-config/home/modules/quickshell/config/dynamic-island";

  # Separate config tree for the session lock, so it runs as its own Quickshell
  # process (launched by quickshell-lock) instead of inside the bar instance.
  xdg.configFile."quickshell-lock".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/git/nixos-config/home/modules/quickshell/config/lock";

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
      Environment = [
        "QT_QPA_PLATFORMTHEME=gtk3"
        "QUICKSHELL_EMOJI_DATA=${emojiData}"
      ];
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
