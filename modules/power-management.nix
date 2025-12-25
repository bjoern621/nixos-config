{ ... }:

{
    # See also: https://wiki.nixos.org/wiki/Laptop#Power_management
    
    powerManagement.enable = true;

    # "TLP is a feature-rich utility for Linux, saving laptop battery power without the need to delve deeper into technical details."
    # "Has sensible defaults for most laptops."
    services.tlp.enable = true;
}