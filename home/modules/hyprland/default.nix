{
  inputs,
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./hyprpaper.nix
    ./app-launcher.nix
    ./keybinds.nix
    ./animations.nix
    ./clipboard-history.nix
    ./preferred-workspaces.nix
    ./hyprpolkit.nix
    ./monitors.nix
    ./no_update_notice.nix
    ./windowrules.nix
    ./disable_middle_click_paste.nix
    ./media-keys.nix
    ./brightness-keys.nix
    ./standard-apps.nix
    ./mouse-cursor.nix
    ./settings/default.nix
    ./mouse-accel.nix
    ./screenshot.nix
    ./exclusive-workspace.nix
    ./smart-gaps.nix
    ./wallpaper-chooser.nix
    ./hyprlock.nix
  ];

  # Auto-start Hyprland uwsm after login
  # https://www.youtube.com/watch?v=7QLhCgDMqgw
  # https://wiki.hypr.land/Useful-Utilities/Systemd-start/#in-tty
  # Already done by display manager.
  # programs.zsh = {
  #   enable = true;
  #   profileExtra = ''
  #     if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
  #       exec uwsm start hyprland-uwsm.desktop
  #     fi
  #   '';
  # };

  # https://wiki.hypr.land/Nix/Hyprland-on-Home-Manager/#nixos-uwsm
  xdg.configFile."uwsm/env".source =
    "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

  # Hide uuctl (from uwsm, enabled in modules/hyprland.nix) from the app launcher
  xdg.desktopEntries."uuctl" = {
    name = "uuctl";
    exec = "uuctl";
    noDisplay = true;
    type = "Application";
  };

  wayland.windowManager.hyprland = {
    enable = true;

    # https://wiki.hypr.land/Useful-Utilities/Systemd-start/#uwsm
    systemd.enable = false;
  };
}
