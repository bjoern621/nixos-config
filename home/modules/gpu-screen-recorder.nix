{
  config,
  lib,
  pkgs,
  ...
}:

# Note: the setcap wrapper KMS capture needs lives in modules/gpu-screen-recorder.nix.
let
  # Monitor games run on. Description survives cable moving to another port.
  monitor = "LG Electronics LG ULTRAGEAR 308MAPN9YD64";
  replayDir = "${config.xdg.userDirs.videos}/Replays";

  notifySaved = pkgs.writeShellScript "gpu-screen-recorder-notify-saved" ''
    ${lib.getExe pkgs.libnotify} --app-name="GPU Screen Recorder" "Clip gespeichert" "$(basename "$1")"
  '';

  startReplay = pkgs.writeShellScript "gpu-screen-recorder-replay" ''
    set -euo pipefail
    output=$(hyprctl -j monitors | ${lib.getExe pkgs.jq} -r --arg desc ${lib.escapeShellArg monitor} '.[] | select(.description == $desc) | .name')
    if [ -z "$output" ]; then
      echo "Monitor ${monitor} not connected" >&2
      exit 1
    fi
    mkdir -p ${lib.escapeShellArg replayDir}

    # h264: every player and Discord embed decodes it.
    # CBR caps buffer at bitrate times duration: 20 Mbps over 1800 s holds about 4.5 GB of RAM.
    # Game, voice chat and mic share one track, since most players play only the first.
    exec ${lib.getExe pkgs.gpu-screen-recorder} \
      -w "$output" \
      -f 60 \
      -c mp4 \
      -k h264 \
      -bm cbr \
      -q 20000 \
      -a "default_output|default_input" \
      -ac aac \
      -r 1800 \
      -replay-storage ram \
      -o ${lib.escapeShellArg replayDir} \
      -sc ${notifySaved} \
      -v no
  '';
in
{
  systemd.user.services.gpu-screen-recorder-replay = {
    Unit = {
      Description = "GPU Screen Recorder replay buffer";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = startReplay;
      # Upstream unit stops gpu-screen-recorder with SIGINT.
      KillSignal = "SIGINT";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.desktopEntries."gpu-screen-recorder-save-replay" = {
    name = "Replay speichern";
    comment = "Speichert die letzten 30 Minuten (ALT+F10)";
    exec = "systemctl --user kill --kill-whom=main --signal=SIGUSR1 gpu-screen-recorder-replay.service";
    icon = "com.dec05eba.gpu_screen_recorder";
    type = "Application";
    categories = [
      "AudioVideo"
      "Video"
    ];
    settings.Keywords = "shadowplay;replay;clip;aufnahme;speichern";
  };

  wayland.windowManager.hyprland.extraLuaFiles."gpu-screen-recorder".content = ./gpu-screen-recorder.lua;
}
