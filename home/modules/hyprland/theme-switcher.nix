{ ... }:

{
  xdg.desktopEntries."theme-switcher" = {
    name = "Design ändern";
    exec = "qs ipc call theme toggle";
    icon = "preferences-desktop-theme";
    type = "Application";
    categories = [ "Settings" ];
    settings.Keywords = "theme;design;style;neobrutalism;klassisch;theme-switcher";
  };
}
