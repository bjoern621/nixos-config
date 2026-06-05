{ ... }:

{
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    # Keep exporting XDG_*_DIR session variables. The default flipped to false
    # for stateVersion >= 26.05.
    setSessionVariables = true;
  };
}
