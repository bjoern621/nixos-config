{ pkgs, ... }:

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

  wayland.windowManager.hyprland.extraLuaFiles."rules.33-chrome-bitwarden".content =
    ./google-chrome.lua;
}
