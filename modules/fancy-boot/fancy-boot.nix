{ pkgs, ... }:

{
  boot = {
    plymouth = {
      enable = true;
      theme = "ccpenguin";
      themePackages = [
        (pkgs.callPackage ./ccpenguin-theme.nix { })
      ];
    };

    # Enable "Silent boot"
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "udev.log_priority=3"
      # Theme sizes itself per display height.
      # Scale 2 on eDP-1 would upscale its images after that.
      "plymouth.force-scale=1"
    ];

    # Hide the OS choice for bootloaders.
    # It's still possible to open the bootloader list by pressing any key
    # It will just not appear on screen unless a key is pressed
    # Instantly select latest NixOS profile
    loader.timeout = 0;
  };
}
