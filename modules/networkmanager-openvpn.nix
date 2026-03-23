{ pkgs, ... }:

/*
  NetworkManager OpenVPN plugin for importing and managing OpenVPN connections.
  Import .ovpn files with: nmcli connection import type openvpn file <path>
*/

{
  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];
}
