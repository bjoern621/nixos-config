{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "float on, match:class mpv"
      # float is a static effect, evaluated only at window creation using initialTitle/initialClass.
      # Bitwarden's initialTitle is "_crx_nngceckbapebfimnlniiiahkandclblb", not "Bitwarden",
      # so match:title won't work. Must use match:class instead.
      # See: https://wiki.hypr.land/Configuring/Window-Rules/#static-effects
      "float on, match:class chrome-nngceckbapebfimnlniiiahkandclblb-Default"
    ];
  };
}