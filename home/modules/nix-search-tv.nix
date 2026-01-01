{ pkgs, ... }:

let
  ns = pkgs.writeShellScriptBin "ns" ''
    ${pkgs.nix-search-tv}/nixpkgs.sh
  '';
in
{
  # https://github.com/3timeslazy/nix-search-tv

  # TODO use flake so that not only bin/nix-search is imported

  home.packages = with pkgs; [
    nix-search-tv
    fzf
    ns
  ];
}