{
  # XDG autostart for same reason as autostart.nix.
  xdg.configFile."autostart/code.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Visual Studio Code
    Exec=uwsm app -- code.desktop
  '';

  # Workspace 2 reserved for VSCode.
  wayland.windowManager.hyprland.extraLuaFiles."rules.10-exclusive-workspace".content =
    ./exclusive-workspace.lua;
}
