{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    swappy # Screenshot editing
    grim # Capture image from screen
    slurp # Area selection tool, outputting coordinates to grim
    wayfreeze # Freeze screen for screenshot selection
  ];

  wayland.windowManager.hyprland.settings = {
    bind = [
      # Screenshot
      "$mainMod SHIFT, S, exec, grim -g \"$(slurp)\" - | swappy -f -"
      # Screenshot with frozen screen (Windows-style)
      "$mainMod CTRL SHIFT, S, exec, FILE=/tmp/frozen-screenshot.png; wayfreeze & PID=$!; sleep .1; grim -g \"$(slurp)\" \"$FILE\"; kill $PID; swappy -f \"$FILE\"; rm \"$FILE\""
    ];
  };
}
