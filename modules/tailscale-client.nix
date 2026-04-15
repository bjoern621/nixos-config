{ pkgs, ... }:

{
  services.tailscale = {
    enable = true;
    # Needed for tailscale systray to work without root permissions, see
    # https://tailscale.com/docs/reference/troubleshooting/linux/linux-operator-permission
    extraSetFlags = [ "--operator=bjoern" ];
  };
}
