{ config, pkgs, ... }:

{
  wayland.windowManager.hyprland.settings = {
    # Variables
    "$mainMod" = "SUPER";
    "$terminal" = "alacritty";
    "$fileManager" = "nautilus";

    # See https://wiki.hypr.land/Configuring/Binds/
    # Follows scheme: bind = MODS, key, dispatcher, params
    bind = [
      # Application shortcuts
      "$mainMod, Q, exec, $terminal"
      "$mainMod, W, killactive,"
      "$mainMod, M, exit,"

      # Move focus with mainMod + arrow keys
      "$mainMod, left, movefocus, l"
      "$mainMod, right, movefocus, r"
      "$mainMod, up, movefocus, u"
      "$mainMod, down, movefocus, d"

      # Move current workspace to another monitor with CTRL + SUPER + arrow keys
      "$mainMod CTRL, left, moveworkspacetomonitor, l"
      "$mainMod CTRL, right, moveworkspacetomonitor, r"

      # Switch workspaces with mainMod + [0-9]
      "$mainMod, 1, workspace, 1"
      "$mainMod, 2, workspace, 2"
      "$mainMod, 3, workspace, 3"
      "$mainMod, 4, workspace, 4"
      "$mainMod, 5, workspace, 5"
      "$mainMod, 6, workspace, 6"
      "$mainMod, 7, workspace, 7"
      "$mainMod, 8, workspace, 8"
      "$mainMod, 9, workspace, 9"
      "$mainMod, 0, workspace, 10"

      # Move active window to a workspace with mainMod + SHIFT + [0-9]
      "$mainMod SHIFT, 1, movetoworkspace, 1"
      "$mainMod SHIFT, 2, movetoworkspace, 2"
      "$mainMod SHIFT, 3, movetoworkspace, 3"
      "$mainMod SHIFT, 4, movetoworkspace, 4"
      "$mainMod SHIFT, 5, movetoworkspace, 5"
      "$mainMod SHIFT, 6, movetoworkspace, 6"
      "$mainMod SHIFT, 7, movetoworkspace, 7"
      "$mainMod SHIFT, 8, movetoworkspace, 8"
      "$mainMod SHIFT, 9, movetoworkspace, 9"
      "$mainMod SHIFT, 0, movetoworkspace, 10"

      # Screenshot
      "$mainMod SHIFT, S, exec, grim -g \"$(slurp)\" - | swappy -f -"
    ];

    # Allow moving windows with the left mouse button
    # LMB -> 272
    # RMB -> 273
    # MMB -> 274
    # Extra MB -> 275, 276, ...

    binds.drag_threshold = 10; # Fire a drag event only after dragging for more than 10px

    # bindm = bind mouse
    bindm = [
      "SUPER, mouse:272, movewindow"
      "SUPER, mouse:273, resizewindow"
      ", mouse:276, movewindow"
      ", mouse:275, resizewindow"
    ];

    # bindc = bind mouse click (clicked (pressed and released) without dragging beyond the drag threshold)
    bindc = [
      "SUPER, mouse:272, togglefloating"
      ", mouse:276, togglefloating"
    ];
  };
}
