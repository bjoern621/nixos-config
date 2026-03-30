{ ... }:

{
  xdg.desktopEntries."wallpaper-chooser" = {
    name = "Hintergrundbild ändern";
    exec = "qs ipc call wallpaper toggle";
    icon = "image-x-generic";
    type = "Application";
    categories = [ "Settings" ];
    settings.Keywords = "wallpaper;desktop;hintergrund;background;wallpaper-chooser";
  };
}
