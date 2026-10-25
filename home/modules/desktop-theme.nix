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

let
  # Holds no icons. Searches hicolor first, where apps install their own icons;
  # Papirus covers only names that no app ships.
  # Qt moves hicolor to the end of a theme's own Inherits list.
  # Reached through hicolor-first, a parent searched depth-first, it stays ahead of Papirus.
  papirusFallback = base: {
    "icons/${base}-Fallback/index.theme".text = ''
      [Icon Theme]
      Name=${base}-Fallback
      Comment=App icons from hicolor, missing ones from ${base}
      Inherits=hicolor-first,${base}
      Directories=
    '';
  };
in
{
  # Papirus-Fallback serves Quickshell (see quickshell.nix).
  xdg.dataFile = {
    "icons/hicolor-first/index.theme".text = ''
      [Icon Theme]
      Name=hicolor-first
      Comment=Searches hicolor alone
      Inherits=hicolor
      Directories=
    '';
  }
  // papirusFallback "Papirus-Dark"
  // papirusFallback "Papirus";

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
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark-Fallback";
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

  # Papirus-Dark inherits breeze-dark for icons it lacks, such as KDE app names.
  home.packages = [ pkgs.kdePackages.breeze-icons ];

  # https://wiki.hypr.land/Nix/Hyprland-on-Home-Manager/#fixing-problems-with-themes
  home.pointerCursor = {
    enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;

    # Applies the cursor theme through GTK settings (GTK apps, portals, and many desktop components).
    gtk.enable = true;

    # Exports Xcursor settings for X11/XWayland clients (some Electron/legacy apps still read Xcursor).
    x11.enable = true;
  };
}
