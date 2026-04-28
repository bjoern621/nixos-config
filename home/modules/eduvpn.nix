{ pkgs, ... }:

{
  home.packages = [ pkgs.eduvpn-client ];

  # eduvpn-client ships a second desktop entry for "Let's Connect!" (white-label rebrand of eduVPN for non-edu orgs). I don't want it in my app launcher, so hide it.
  xdg.desktopEntries."org.letsconnect-vpn.client" = {
    name = "Let's Connect!";
    noDisplay = true;
  };
}
