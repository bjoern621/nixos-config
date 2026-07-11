# Find which package provides a command (nix-search-tv only indexes package
# names/descriptions, not the files inside packages):
#   nix-locate bin/nslookup    -> lists providing packages (bind, dnsutils)
#   , nslookup example.com     -> comma: run a command without installing it
# Missing commands in zsh get the same lookup via command_not_found_handler.
# nix-index-database ships a prebuilt weekly database; no local index build.
{ inputs, ... }:

{
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;
  programs.command-not-found.enable = false;
}
