{ pkgs, ... }:

{
  programs.chromium = {
    enable = true;
    package = pkgs.google-chrome;

    # Set chrome://flags
    commandLineArgs = [
      "--disable-features=HardwareMediaKeyHandling"
    ];
  };
}
