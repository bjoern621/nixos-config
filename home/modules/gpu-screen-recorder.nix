{
  config,
  lib,
  pkgs,
  ...
}:

# Note: the setcap wrapper KMS capture needs lives in modules/gpu-screen-recorder.nix.
let
  replayDir = "${config.xdg.userDirs.videos}/Replays";

  # PipeWire application.name of each app with its own track, matched case-insensitively.
  # Discord voice streams carry WEBRTC VoiceEngine.
  apps = {
    discord = [
      "Discord"
      "WEBRTC VoiceEngine"
    ];
    spotify = [ "Spotify" ];
    chrome = [ "Google Chrome" ];
  };
  appTrack = names: lib.concatMapStringsSep "|" (name: "app:${name}") names;
  # Games report a name each.
  # Game track takes every app left out of apps.
  gameTrack = lib.concatMapStringsSep "|" (name: "app-inverse:${name}") (
    lib.flatten (lib.attrValues apps)
  );

  # monitor matches EDID description, which survives cable moving to another port.
  replays = {
    gaming = {
      monitor = "LG Electronics LG ULTRAGEAR 308MAVD9YD63";
      fps = 60;
      bitrateKbps = 40000;
      # One track per entry.
      # Players and Discord embeds play only the first.
      # First track mixes everything.
      audioTracks = [
        "default_output|default_input"
        gameTrack
      ]
      ++ map appTrack (lib.attrValues apps)
      ++ [ "default_input" ];
    };
    # Lower fps and bitrate leave RAM for the game.
    # Gaming clip already carries all audio.
    secondary = {
      monitor = "LG Electronics LG ULTRAGEAR 308MAPN9YD64";
      fps = 30;
      bitrateKbps = 15000;
      audioTracks = [ ];
    };
  };

  notifySaved = pkgs.writeShellScript "gpu-screen-recorder-notify-saved" ''
    ${lib.getExe pkgs.libnotify} --app-name="GPU Screen Recorder" "Clip gespeichert" "$(basename "$(dirname "$1")")/$(basename "$1")"
  '';

  # gsr names replays by the second.
  # Own folder per monitor keeps simultaneous saves apart.
  startReplay =
    name:
    {
      monitor,
      fps,
      bitrateKbps,
      audioTracks,
    }:
    let
      outputDir = "${replayDir}/${name}";
      # AV1 looks sharper than h264 at same bitrate.
      # Stock Windows and older phones cannot decode it.
      # Full range keeps all 256 levels.
      # Players ignoring range flag crush blacks.
      # -tune works on NVIDIA only. Both monitors hang off RTX 5080.
      # CBR caps buffer at bitrate times duration: 40 Mbps over 1800 s holds about 9 GB of RAM.
      args = [
        "-f"
        (toString fps)
        "-c"
        "mp4"
        "-k"
        "av1"
        "-cr"
        "full"
        "-tune"
        "quality"
        "-bm"
        "cbr"
        "-q"
        (toString bitrateKbps)
      ]
      ++ lib.concatMap (track: [
        "-a"
        track
      ]) audioTracks
      ++ lib.optionals (audioTracks != [ ]) [
        "-ac"
        "aac"
      ]
      ++ [
        "-r"
        "1800"
        "-replay-storage"
        "ram"
        "-o"
        outputDir
        "-sc"
        "${notifySaved}"
        "-v"
        "no"
      ];
    in
    pkgs.writeShellScript "gpu-screen-recorder-replay-${name}" ''
      set -euo pipefail
      output=$(hyprctl -j monitors | ${lib.getExe pkgs.jq} -r --arg desc ${lib.escapeShellArg monitor} '.[] | select(.description == $desc) | .name')
      if [ -z "$output" ]; then
        echo "Monitor ${monitor} not connected" >&2
        exit 1
      fi
      mkdir -p ${lib.escapeShellArg outputDir}
      exec ${lib.getExe pkgs.gpu-screen-recorder} -w "$output" ${lib.escapeShellArgs args}
    '';
in
{
  systemd.user.services = lib.mapAttrs' (
    name: replay:
    lib.nameValuePair "gpu-screen-recorder-replay-${name}" {
      Unit = {
        Description = "GPU Screen Recorder replay buffer of ${replay.monitor}";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = startReplay name replay;
        # Upstream unit stops gpu-screen-recorder with SIGINT.
        KillSignal = "SIGINT";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    }
  ) replays;

  xdg.desktopEntries."gpu-screen-recorder-save-replay" = {
    name = "Replay speichern";
    comment = "Speichert die letzten 30 Minuten (ALT+F10)";
    exec = "systemctl --user kill --kill-whom=main --signal=SIGUSR1 \"gpu-screen-recorder-replay-*.service\"";
    icon = "com.dec05eba.gpu_screen_recorder";
    type = "Application";
    categories = [
      "AudioVideo"
      "Video"
    ];
    settings.Keywords = lib.concatStringsSep ";" [
      "shadowplay"
      "instant replay"
      "replay"
      "clip"
      "save"
      "record"
      "recording"
      "capture"
      "highlight"
      "video"
      "gpu screen recorder"
      "speichern"
      "sichern"
      "aufnahme"
      "aufnehmen"
      "mitschnitt"
      "bildschirmaufnahme"
      "wiederholung"
    ];
  };

  wayland.windowManager.hyprland.extraLuaFiles."gpu-screen-recorder".content =
    ./gpu-screen-recorder.lua;
}
