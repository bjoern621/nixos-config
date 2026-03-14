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
    ./settings/decoration.nix
    ./settings/general.nix
    ./mouse-accel.nix
    ./settings/input.nix
  ];

  # Auto-start Hyprland uwsm after login
  # https://www.youtube.com/watch?v=7QLhCgDMqgw
  # https://wiki.hypr.land/Useful-Utilities/Systemd-start/#in-tty
  # Already done by display manager.
  # programs.bash = {
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

  wayland.windowManager.hyprland = {
    enable = true;

    # https://wiki.hypr.land/Useful-Utilities/Systemd-start/#uwsm
    systemd.enable = false;
  };
}
