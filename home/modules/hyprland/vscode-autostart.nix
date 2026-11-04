{ config, lib, ... }:

{
  # Workspace 2 reserved for VSCode only where VSCode autostarts there.
  wayland.windowManager.hyprland.extraLuaFiles."rules.10-exclusive-workspace" =
    lib.mkIf config.host.vscodeAutostart {
      content = ./exclusive-workspace.lua;
    };
}
