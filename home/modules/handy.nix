{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Handy rewrites settings_store.json on every setting change, so a store symlink would fail with EROFS.
  # Seed instead: patch the keys, leave the rest to the app.
  # Tauri store nests everything under "settings".
  # A partial ShortcutBinding fails deserialization and the salvage path resets the whole bindings map,
  # so the seed writes all five fields.
  seedSettings = pkgs.writeShellScript "handy-seed-settings" ''
    set -euo pipefail
    store="$1"
    mkdir -p "$(dirname "$store")"
    [ -e "$store" ] || echo '{}' > "$store"
    tmp="$(mktemp)"
    ${lib.getExe pkgs.jq} '
      .settings.push_to_talk = false
      | .settings.bindings.transcribe = (
          (.settings.bindings.transcribe // {
            id: "transcribe",
            name: "Transcribe",
            description: "Converts your speech into text.",
            default_binding: "ctrl+space"
          }) + { current_binding: "super+s" }
        )
    ' "$store" > "$tmp"
    mv "$tmp" "$store"
  '';
in
{
  home.packages = with pkgs; [
    handy
    wtype # Handy's Direct paste method types transcriptions through it
  ];

  wayland.windowManager.hyprland.extraLuaFiles."handy".content = ./handy.lua;

  # push_to_talk false = toggle: one press starts recording, next one stops.
  # current_binding mirrors the Hyprland bind so the GUI shows the real key,
  # and Handy stops grabbing ctrl+space inside XWayland clients.
  # A running Handy holds its settings in memory and writes them back, so the seed lands on next start.
  home.activation.handySettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${seedSettings} ${config.xdg.configHome}/com.pais.handy/settings_store.json
  '';
}
