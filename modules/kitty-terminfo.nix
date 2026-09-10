# ssh carries the client's TERM across unchanged,
# so a kitty session lands on the server as `xterm-kitty`.
# Without the matching terminfo entry zsh's line editor has no cursor movement
# and echoes every keypress a second time.

{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.kitty.terminfo ];
}
