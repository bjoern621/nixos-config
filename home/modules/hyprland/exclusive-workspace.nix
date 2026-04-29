{
  # Named windowrule so it runs before anonymous `tile on` rules in preferred-workspaces.nix, which then overwrite floating for apps that don't want float.
  wayland.windowManager.hyprland.extraConfig = ''
    windowrule {
      name = exclusive-ws2-float
      match:workspace = 2
      match:class = negative:^code
      float = on
    }
  '';
}
