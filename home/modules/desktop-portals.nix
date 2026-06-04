# XDG Desktop Portals and toolkit integration for Hyprland.
#
# Hyprland provides its own portal (xdg-desktop-portal-hyprland) for
# screencopy and window management, but it does NOT implement:
#   - FileChooser  (native file picker dialogs)
#   - Settings     (color-scheme, font, cursor — see desktop-theme.nix)
#   - AppChooser, Email, etc.
#
# xdg-desktop-portal-gtk fills these gaps. It reads its values from dconf
# (set in desktop-theme.nix) and serves them over D-Bus to any app that
# queries the portal.
#
# Qt integration:
#   platformTheme "gtk3" makes Qt apps use:
#     - The GTK file picker (via the portal) instead of Qt's built-in one
#     - GTK icon theme and font settings
#   This is set here for all Qt apps, and also in the Quickshell systemd
#   service (quickshell.nix) which needs it for icon resolution.
#
# GSETTINGS_SCHEMA_DIR workaround:
#   NixOS nests schema directories under per-package paths in the Nix store.
#   GLib's default schema lookup doesn't traverse these, so gsettings calls
#   (from the portal, from GTK apps opening file dialogs, etc.) fail silently.
#   We point GLib directly at the two required schema sets:
#     - gsettings-desktop-schemas: base desktop settings (color-scheme, fonts)
#     - gtk3: FileChooser dialog settings (sorting, path bar, etc.)

{ pkgs, ... }:

{
  home.packages = [ pkgs.xdg-desktop-portal-gtk ];

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  home.sessionVariables.GSETTINGS_SCHEMA_DIR = builtins.concatStringsSep ":" [
    "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas"
    "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}/glib-2.0/schemas"
  ];

  # Portal stack lifecycle hardening. Two independent failures leave file
  # dialogs broken for apps that are already running:
  #
  #   1. Backend crash. xdg-desktop-portal-gtk exits with "Error reading events
  #      from display: broken pipe" when its Wayland connection drops (Hyprland
  #      restart, suspend/resume, monitor reconfiguration). The packaged unit
  #      ships Restart=no, so the FileChooser backend stays dead afterwards.
  #
  #   2. Frontend restart. xdg-desktop-portal is PartOf=graphical-session.target,
  #      so any cycle of that target stops and restarts the whole portal stack.
  #      Chromium/Electron apps (Chrome, VSCode, Spotify) cache their D-Bus proxy
  #      to org.freedesktop.portal.Desktop at startup and never reconnect, so a
  #      frontend restart silently kills their open/save/download dialogs until
  #      the app itself is restarted.
  #
  # Clearing PartOf detaches the units from target-restart propagation. They
  # still start on D-Bus activation and still stop with the user manager at
  # logout. Restart=on-failure revives them after a genuine crash; with the
  # frontend now surviving target churn, backend restarts are transparent
  # because the frontend re-resolves the impl backend per request.
  #
  # Drop-ins are used instead of systemd.user.services because a full unit would
  # shadow the package's ExecStart/BusName.
  xdg.configFile =
    let
      lifecycle = ''
        [Unit]
        PartOf=

        [Service]
        Restart=on-failure
        RestartSec=1
      '';
    in
    {
      "systemd/user/xdg-desktop-portal.service.d/lifecycle.conf".text = lifecycle;
      "systemd/user/xdg-desktop-portal-gtk.service.d/lifecycle.conf".text = lifecycle;
      "systemd/user/xdg-desktop-portal-hyprland.service.d/lifecycle.conf".text = lifecycle;
    };
}
