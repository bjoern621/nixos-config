{ pkgs, ... }:

{
  programs.chromium = {
    enable = true;
    package = pkgs.google-chrome;

    # Set chrome://flags
    commandLineArgs = [
      "--disable-features=HardwareMediaKeyHandling"
      "--cipher-suite-blacklist=0xc013,0xc014,0x009c,0x009d,0x002f,0x0035"
    ];
  };

  wayland.windowManager.hyprland.settings.windowrule = [
    # float is a static effect, evaluated only at window creation using initialTitle/initialClass.
    # Bitwarden's initialTitle is "_crx_nngceckbapebfimnlniiiahkandclblb", not "Bitwarden",
    # so match:title won't work. Must use match:class instead.
    # See: https://wiki.hypr.land/Configuring/Window-Rules/#static-effects
    "float on, match:class chrome-nngceckbapebfimnlniiiahkandclblb-Default"
  ];
}
