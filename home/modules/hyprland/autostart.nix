{ ... }:

{
  # Chrome and VSCode are started through XDG autostart (systemd-ordered), not
  # Hyprland exec-once. exec-once fires the moment the compositor initializes,
  # outside the systemd dependency graph, so it raced xdg-desktop-portal startup
  # and the apps came up with their file dialogs permanently broken for the
  # session. As XDG autostart entries they run under xdg-desktop-autostart.target,
  # which desktop-portals.nix orders after the portal is ready.
  #
  # Launching still goes through `uwsm app` so the apps inherit the same scoped
  # environment as before. Workspace placement comes from the class-based window
  # rules in preferred-workspaces.nix (chrome -> 1, code -> 2).
  xdg.configFile = {
    "autostart/google-chrome.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Google Chrome
      Exec=uwsm app -- google-chrome.desktop
    '';
    "autostart/code.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Visual Studio Code
      Exec=uwsm app -- code.desktop
    '';
  };
}
