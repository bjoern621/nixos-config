{ lib, ... }:

{
  dconf.settings."org/gtk/gtk4/settings/file-chooser".show-hidden = true;

  # Kate registers itself as an inode/directory handler, so xdg-open on a folder
  # would launch Kate instead of a file manager. Pin directories to Nautilus.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = "org.gnome.Nautilus.desktop";
      "x-directory/normal" = "org.gnome.Nautilus.desktop";
    };
  };

  xdg.configFile."gtk-3.0/bookmarks".text = ''
    file:///home/bjoern/Downloads
  '';

  home.activation.createDownloads = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/Downloads"
  '';

  # TODO doesnt work
  # nautilus-python loads Python extensions from ~/.local/share/nautilus-python/extensions/.
  # The extension below registers Backspace as an extra accelerator for the win.back action
  # via GTK4's GtkApplication API, entirely inside Nautilus's own process.
  home.file.".local/share/nautilus-python/extensions/backspace_nav.py".text = ''
    import gi
    gi.require_version('Nautilus', '4.1')
    gi.require_version('GObject', '2.0')
    from gi.repository import Nautilus, GObject, Gio

    class BackspaceNavExtension(GObject.GObject, Nautilus.MenuProvider):
        def __init__(self):
            app = Gio.Application.get_default()
            if app:
                existing = list(app.get_accels_for_action("win.back"))
                if "BackSpace" not in existing:
                    app.set_accels_for_action("win.back", existing + ["BackSpace"])

        def get_file_items(self, files):
            return []

        def get_background_items(self, folder):
            return []
  '';

  # Ensure the Nautilus-4.1 typelib is on the GI search path for the Python extension
  home.sessionVariables.GI_TYPELIB_PATH = "/run/current-system/sw/lib/girepository-1.0";
}
