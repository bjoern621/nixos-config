{ ... }:

{
  # Event handler, not a window rule; ordering irrelevant, hence no rules.NN- prefix.
  wayland.windowManager.hyprland.extraLuaFiles."floating-size".content = ./floating-size.lua;
}
