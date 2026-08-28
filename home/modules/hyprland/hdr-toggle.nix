{ pkgs, ... }:

let
  hdr-toggle = pkgs.writeShellScriptBin "hdr-toggle" ''
    # Flips eDP-1 between srgb and hdr cm preset at runtime.
    # Partial hl.monitor spec latches; mode/position/scale/bitdepth stay untouched.
    # HDR is for HDR content sessions (mpv, gamescope) only:
    # OLED draws more power in PQ mode and SDR apps gain nothing.
    # sdrbrightness 1.2 keeps SDR windows readable next to HDR content.
    set -euo pipefail

    preset=$(hyprctl -j monitors | ${pkgs.jq}/bin/jq -r '.[] | select(.name == "eDP-1") | .colorManagementPreset')

    if [ "$preset" = "hdr" ]; then
      hyprctl eval 'hl.monitor({ output = "eDP-1", cm = "srgb", sdrbrightness = 1.0 })' > /dev/null
      ${pkgs.libnotify}/bin/notify-send "HDR" "Ausgeschaltet (sRGB)"
    else
      hyprctl eval 'hl.monitor({ output = "eDP-1", cm = "hdr", sdrbrightness = 1.2 })' > /dev/null
      ${pkgs.libnotify}/bin/notify-send "HDR" "Eingeschaltet (PQ, BT2020)"
    fi
  '';
in
{
  home.packages = [ hdr-toggle ];

  xdg.desktopEntries."hdr-toggle" = {
    name = "HDR umschalten";
    exec = "hdr-toggle";
    icon = "video-display";
    type = "Application";
    categories = [ "Settings" ];
    settings.Keywords = "hdr;oled;10bit;farbe;color;bt2020;hdr-toggle";
  };
}
