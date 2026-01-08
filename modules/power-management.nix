{ ... }:

{
    # See also: https://wiki.nixos.org/wiki/Laptop#Power_management
    
    powerManagement.enable = true;

    # "TLP is a feature-rich utility for Linux, saving laptop battery power without the need to delve deeper into technical details."
    # "Has sensible defaults for most laptops."
    services.tlp = {
      enable = true;
      settings = {
        # Disable audio power saving to prevent audio quality degradation
        SOUND_POWER_SAVE_ON_AC = 0;
        SOUND_POWER_SAVE_ON_BAT = 0;
      };
    };
}