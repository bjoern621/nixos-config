{ ... }:

{
  # Terminal file manager. `y` opens it, `q` lands shell in browsed dir.
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    # Default stays "yy" below stateVersion 26.05.
    shellWrapperName = "y";
  };
}
