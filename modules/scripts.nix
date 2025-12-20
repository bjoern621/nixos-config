{ config, pkgs, ... }:

let
  sys-conf-update = pkgs.writeShellScriptBin "sys-conf-update" ''
    set -e
    
    NIXOS_CONFIG="/etc/nixos"
    
    echo "Pulling latest changes..."
    cd "$NIXOS_CONFIG"
    sudo git pull
    
    echo "Rebuilding NixOS..."
    sudo nixos-rebuild switch --flake "$NIXOS_CONFIG#nixos"
    
    echo "System updated successfully!"
    echo "You may want to reboot now."
  '';
in
{
  environment.systemPackages = [ sys-conf-update ];
}
