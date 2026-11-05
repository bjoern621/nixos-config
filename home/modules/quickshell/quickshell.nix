{
  inputs,
  lib,
  pkgs,
  config,
  customLib,
  ...
}:

let
  qs = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # keyring + secretstorage: Spotify API.
  # pygobject3: calendar_events.py, against the typelibs in giDeps below.
  qsPython = pkgs.python3.withPackages (ps: [
    ps.keyring
    ps.pygobject3
    ps.secretstorage
  ]);

  # Private runtime deps, visible only to the quickshell process and its
  # children, never added to the user's global environment.
  qsWrapped = customLib.wrapWithPrivateDeps qs {
    bin = "quickshell";
    binDeps = [
      pkgs.imagemagick # WallpaperAccent color extraction
      pkgs.curl # NetworkService: captive portal redirect target
      pkgs.libnotify # notify-send for desktop notifications
      pkgs.networkmanager # nmcli: NetworkService reads + monitor + network_backend.py
      pkgs.qrencode # network menu wifi QR code
      pkgs.util-linux # rfkill: airplane mode
      qsPython
    ];
    dataDeps = [
      pkgs.inter # Text
    ];
    # calendar_events.py imports ECal and EDataServer, which pull the rest in.
    # glib and gobject-introspection default to non-out outputs, so name .out;
    # gobject-introspection carries the libxml2 typelib.
    giDeps = [
      pkgs.evolution-data-server
      pkgs.glib.out
      pkgs.gobject-introspection.out
      pkgs.json-glib
      pkgs.libical
      pkgs.libsoup_3
    ];
    qtDeps = [
      pkgs.qt6.qtimageformats # webp decode for WallpaperChooser thumbnails
    ];
  };

  # CLI helper for one-time user setup (setup/auth/clear).
  # This gives the user a python executable that also has keyring+secretstorage available.
  spotifyCli = pkgs.writeShellScriptBin "quickshell-spotify" ''
    exec ${qsPython}/bin/python3 "$HOME/.config/quickshell/spotify_api.py" "$@"
  '';

  # Emoji dataset for the EmojiPicker (Super+.). Built from Unicode's
  # emoji-test.txt + UnicodeData.txt + Blocks.txt + CLDR annotations (en + de)
  # at home-manager rebuild, so updating nixpkgs auto-bumps the dataset.
  emojiData =
    pkgs.runCommand "quickshell-emoji-data.json"
      {
        nativeBuildInputs = [ pkgs.python3 ];
      }
      ''
        python3 ${./gen-emoji.py} \
          ${pkgs.unicode-emoji}/share/unicode/emoji/emoji-test.txt \
          ${pkgs.unicode-character-database}/share/unicode/UnicodeData.txt \
          ${pkgs.unicode-character-database}/share/unicode/Blocks.txt \
          ${pkgs.cldr-annotations}/share/unicode/cldr/common/annotations/en.xml \
          ${pkgs.cldr-annotations}/share/unicode/cldr/common/annotations/de.xml \
          > $out
      '';
in

{
  # User-level quickshell configuration.
  # NOTE: This module is paired with modules/quickshell.nix
  # which contains system-level dependencies like UPower.

  imports = [ ./options.nix ];

  quickshell.package = qsWrapped;

  # Read by PowerController.qml; an action missing here never reaches the menu.
  quickshell.powerActions = [
    "shutdown"
    "reboot"
    "logout"
  ];

  home.packages = [
    qsWrapped # quickshell + private PATH/fonts (imagemagick, python3+keyring, font-awesome, inter)
    spotifyCli # quickshell-spotify: user-facing CLI for setup/auth/clear
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
      # Shell draws on light surfaces, apps on dark ones (gtk.iconTheme Papirus-Dark-Fallback).
      # QS_ICON_THEME overrides the icon theme that gtk3 reads from GTK settings.
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
        "QS_ICON_THEME=Papirus-Fallback"
        "QUICKSHELL_EMOJI_DATA=${emojiData}"
        "QUICKSHELL_POWER_ACTIONS=${lib.concatStringsSep "," config.quickshell.powerActions}"
        "QT_LOGGING_RULES=quickshell.dbus.properties.warning=false"
      ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  wayland.windowManager.hyprland.extraLuaFiles."quickshell-layerrules".content = ./layerrules.lua;
}
