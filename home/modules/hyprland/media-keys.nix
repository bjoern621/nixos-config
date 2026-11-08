{ pkgs, ... }:

let
  volume-step = pkgs.writeShellScriptBin "volume-step" ''
    # Takes up or down.
    # TV sink: sets Denon AVR master volume over telnet.
    # PipeWire volume never reaches AVR over eARC.
    # AVR takes one client. flock drops key repeats during running step.
    # Levels in tenths. Level outside min_level..max_level blocks AVR steps.
    set -euo pipefail

    direction=$1
    avr_host=192.168.178.50
    tv_sink=alsa_output.pci-0000_01_00.1.hdmi-stereo-extra2
    min_level=100
    max_level=600
    step=10

    exec 9>"$XDG_RUNTIME_DIR/volume-step.lock"
    ${pkgs.util-linux}/bin/flock -n 9 || exit 0

    if [[ "$(wpctl inspect @DEFAULT_AUDIO_SINK@)" != *"node.name = \"$tv_sink\""* ]]; then
      if [ "$direction" = up ]; then sign=+; else sign=-; fi
      wpctl set-volume @DEFAULT_AUDIO_SINK@ "5%$sign"
      exit
    fi

    coproc avr { ${pkgs.netcat-openbsd}/bin/nc -w 2 "$avr_host" 23; }
    avr_pid=$avr_PID
    trap 'kill "$avr_pid" 2>/dev/null || true' EXIT
    avr_in=''${avr[1]}
    avr_out=''${avr[0]}

    printf 'MV?\r' >&"$avr_in"
    level=""
    while IFS= read -r -t 1 -d $'\r' -u "$avr_out" line; do
      if [[ "$line" =~ ^MV([0-9]{2,3})$ ]]; then
        level=''${BASH_REMATCH[1]}
        break
      fi
    done
    [ -n "$level" ] || exit 1

    # AVR reports 48.5 as 485 and 48.0 as 48.
    if [ ''${#level} -eq 2 ]; then level=''${level}0; fi
    level=$((10#$level))
    if [ "$level" -lt "$min_level" ] || [ "$level" -gt "$max_level" ]; then exit 1; fi

    if [ "$direction" = up ]; then
      target=$((level + step))
      if [ "$target" -gt "$max_level" ]; then target=$max_level; fi
    else
      target=$((level - step))
      if [ "$target" -lt "$min_level" ]; then target=$min_level; fi
    fi
    [ "$target" -ne "$level" ] || exit 0

    if [ $((target % 10)) -eq 0 ]; then
      printf 'MV%02d\r' $((target / 10)) >&"$avr_in"
    else
      printf 'MV%03d\r' "$target" >&"$avr_in"
    fi

    # Echo proves AVR took command before EXIT trap closes connection.
    while IFS= read -r -t 1 -d $'\r' -u "$avr_out" line; do
      if [[ "$line" =~ ^MV[0-9] ]]; then break; fi
    done
  '';
in
{
  home.packages = [
    pkgs.playerctl
    volume-step
  ];

  wayland.windowManager.hyprland.extraLuaFiles."media-keys".content = ./media-keys.lua;
}
