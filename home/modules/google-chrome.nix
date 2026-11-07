{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Running Chrome holds Preferences in memory and writes them back on exit, so seed only while closed.
  # SingletonLock exists while Chrome runs.
  seedPrefs =
    name: filter:
    pkgs.writeShellScript "chrome-seed-${name}" ''
      set -euo pipefail
      dir="$1"
      [ -L "$dir/SingletonLock" ] && exit 0
      for prefs in "$dir"/*/Preferences; do
        [ -f "$prefs" ] || continue
        tmp="$(mktemp)"
        ${lib.getExe pkgs.jq} -c '${filter}' "$prefs" > "$tmp"
        mv "$tmp" "$prefs"
      done
    '';

  # Chrome 154 has no policy for vertical tabs, only per-profile pref `vertical_tabs.enabled`.
  seedVerticalTabs = seedPrefs "vertical-tabs" ".vertical_tabs.enabled = true";

  # Chrome binds Ctrl+Shift+L to collapsing vertical tabs and skips it when assigning Bitwarden's suggested keys.
  # A user binding of an extension outranks Chrome's own shortcut.
  seedBitwardenAutofillShortcut = seedPrefs "bitwarden-autofill-shortcut" ''
    .extensions.commands["linux:Ctrl+Shift+L"] = {
      command_name: "autofill_login",
      extension: "nngceckbapebfimnlniiiahkandclblb",
      global: false
    }
  '';
in
{
  programs.chromium = {
    enable = true;
    package = pkgs.google-chrome;

    # Set chrome://flags
    commandLineArgs = [
      "--disable-features=HardwareMediaKeyHandling"
      "--cipher-suite-blacklist=0xc013,0xc014,0x009c,0x009d,0x002f,0x0035"
      # HDR canvas/media APIs (testufo HDR test needs them).
      "--enable-experimental-web-platform-features"
    ];
  };

  # Runs on every switch and boot, so vertical tabs return after toggling off.
  home.activation.chromeVerticalTabs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${seedVerticalTabs} ${config.xdg.configHome}/google-chrome
  '';

  home.activation.chromeBitwardenAutofillShortcut = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${seedBitwardenAutofillShortcut} ${config.xdg.configHome}/google-chrome
  '';

  wayland.windowManager.hyprland.extraLuaFiles."rules.33-chrome-bitwarden".content =
    ./google-chrome.lua;
}
