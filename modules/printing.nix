{ ... }:

{
  # Printing and auto-discovery (network via mDNS and modern USB IPP printers)
  services.printing = {
    enable = true;
    browsing = true;
    openFirewall = true;
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.ipp-usb.enable = true;
}
