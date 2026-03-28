{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      # Float common dialog windows (file pickers, save dialogs, etc.)
      "float on, match:title (Datei öffnen|Speichern unter|Ordner öffnen|Open File|Open Folder|Save As|Save File)"
      "float on, match:class .blueman-manager-wrapped"
    ];
  };
}
