{ pkgs, ... }:

/*
  Uses wg-quick via configFile — the conf path is resolved at service start,
  not at eval time, so pure flake evaluation is not violated.

  The conf file lives at /etc/wireguard/wg-hamburg.conf (outside the git repo).
  See modules/wireguard.conf.example for the template.

  Setup:
    sudo mkdir -p /etc/wireguard
    sudo cp modules/wireguard.conf.example /etc/wireguard/wg-hamburg.conf
    sudo chmod 600 /etc/wireguard/wg-hamburg.conf
    # edit the file and fill in real keys

  Manage:
    systemctl start|stop|status wg-quick-wg-hamburg
    wg show
*/

{
  networking.wg-quick.interfaces.wg-hamburg.configFile = "/etc/wireguard/wg-hamburg.conf";
  environment.systemPackages = [ pkgs.wireguard-tools ]; # provides wg and wg-quick
}
