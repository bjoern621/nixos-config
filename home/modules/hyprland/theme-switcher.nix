{ ... }:

{
  xdg.desktopEntries."theme-switcher" = {
    name = "Design ändern";
    exec = "qs ipc call theme toggle";
    icon = "org.gnome.design.Palette";
    type = "Application";
    categories = [ "Settings" ];
    settings.Keywords = "theme;design;style;neobrutalism;klassisch;theme-switcher";
  };
}
