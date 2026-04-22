# Desktop appearance: GTK theme, icon theme, cursor, and dark mode preference.
#
# On Wayland without a full desktop environment (e.g. Hyprland), there is no
# central settings daemon. Apps discover the preferred color scheme through
# multiple independent mechanisms:
#
#   1. GTK theme name — GTK3 apps infer dark mode from the theme name.
#   2. dconf / gsettings — GTK4/libadwaita apps read
#      org.gnome.desktop.interface.color-scheme directly.
#   3. XDG Desktop Portal — Chromium, Electron, Firefox, and other modern apps
#      query org.freedesktop.appearance.color-scheme over D-Bus.
#      xdg-desktop-portal-gtk (see desktop-portals.nix) serves this by reading
#      the same dconf key from (2).
#
# All three must agree. The GTK theme is set via Home Manager's gtk module,
# and the dconf key is set explicitly so the portal reports dark mode correctly.

{ pkgs, ... }:

{
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
  };

  gtk = {
    enable = true;

    theme = {
      package = pkgs.gnome-themes-extra;
      name = "Adwaita-dark";
    };

    iconTheme = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
    };

    font = {
      name = "Inter";
      size = 11;
    };

    gtk4.theme = {
      package = pkgs.gnome-themes-extra;
      name = "Adwaita-dark";
    };
  };

  # https://wiki.hypr.land/Nix/Hyprland-on-Home-Manager/#fixing-problems-with-themes
  home.pointerCursor = {
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;

    # Applies the cursor theme through GTK settings (GTK apps, portals, and many desktop components).
    gtk.enable = true;

    # Exports Xcursor settings for X11/XWayland clients (some Electron/legacy apps still read Xcursor).
    x11.enable = true;
  };
}
