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

  lockShell = "${config.home.homeDirectory}/.config/quickshell-lock/shell.qml";

  # Session-lock trigger. Engages the lock on the resident quickshell-lock
  # instance (systemd user service below) over IPC, rather than spawning a fresh
  # Quickshell. The resident instance is already Wayland-connected, so locking is
  # an instant state flip; cold-spawning during the suspend/hibernate window used
  # to race the freeze and die on resume. Idempotent: the IPC handler ignores a
  # lock call when already locked, so repeated lock-session signals do not stack.
  quickshellLock = pkgs.writeShellScriptBin "quickshell-lock" ''
    exec ${qsWrapped}/bin/quickshell ipc -p "${lockShell}" call lock lock
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
      #
      # Chromium-based tray apps (Discord, Electron) publish their icon only as
      # StatusNotifierItem.IconPixmap and leave IconName unimplemented, so its
      # getter returns a D-Bus error instead of an empty string. Discord also
      # re-emits NewIcon several times per second, and Quickshell refetches the
      # property on every signal, logging a warning each time (~40/min). The
      # tray icon itself renders from IconPixmap and is unaffected.
      # The dbus.properties category carries nothing else, so it is dropped
      # wholesale; remove this rule when debugging tray property updates.
      Environment = [
        "QT_QPA_PLATFORMTHEME=gtk3"
        "QUICKSHELL_EMOJI_DATA=${emojiData}"
        "QT_LOGGING_RULES=quickshell.dbus.properties.warning=false"
      ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Resident session-lock instance. Runs the lock config (config/lock) as its own
  # long-lived Quickshell process, separate from the bar so a bar reload or crash
  # cannot affect the lock and vice versa. It sits idle (locked = false, no
  # surfaces) until the quickshell-lock command flips it via IPC.
  #
  # Restart=on-failure recovers an idle crash so the lock is always available. A
  # crash while locked is held by the compositor (the session stays locked, as
  # with any session-lock client), so a restart cannot bypass it.
  systemd.user.services.quickshell-lock = {
    Unit = {
      Description = "Quickshell session lock (resident)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${qsWrapped}/bin/quickshell -p ${lockShell}";
      Restart = "on-failure";
      RestartSec = 1;
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
