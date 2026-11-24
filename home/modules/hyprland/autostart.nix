{
  # Chrome starts via XDG autostart, not Hyprland exec-once.
  # exec-once fires at compositor init, outside systemd graph.
  # It raced xdg-desktop-portal startup and broke file dialogs for whole session.
  # XDG autostart runs under xdg-desktop-autostart.target.
  # desktop-portals.nix orders that target after portal ready.
  #
  # `uwsm app` gives Chrome same scoped environment as other apps.
  # Workspace placement comes from class rules in preferred-workspaces.nix.
  xdg.configFile."autostart/google-chrome.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Google Chrome
    Exec=uwsm app -- google-chrome.desktop
  '';
}
