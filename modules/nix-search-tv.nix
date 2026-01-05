{ inputs, pkgs, ... }:

let
  ns = pkgs.writeShellScriptBin "ns" ''
    ${inputs.nix-search-tv}/nixpkgs.sh "$@"
  '';
in
{
  environment.systemPackages = [ pkgs.nix-search-tv pkgs.fzf ns ];
}