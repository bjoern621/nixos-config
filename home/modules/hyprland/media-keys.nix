{ pkgs, ... }:

{
  home.packages = [
    pkgs.playerctl
  ];

  wayland.windowManager.hyprland.settings = {
    # l -> do stuff even when locked
    # e -> repeats when key is held
    bindel = [
      ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
      ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
    ];

    # l -> do stuff even when locked
    bindl = [
      ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ", XF86AudioNext, exec, playerctl next"
      ", XF86AudioPrev, exec, playerctl previous"
      ", XF86AudioPlay, exec, playerctl play-pause"
    ];
  };
}
