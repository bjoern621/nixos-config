{ pkgs, ... }:

{
  # https://nixos.wiki/wiki/Git

  programs.git = {
    enable = true;

    settings = {
      user = {
        name  = "Björn";
        email = "41452212+bjoern621@users.noreply.github.com";
      };
      init.defaultBranch = "main";
    };

    # Configure git-credential-helper with libsecret
    # Allows storing the git password and not needing to retype it over and over again
    config = {
      credential.helper = "${
          pkgs.git.override { withLibsecret = true; }
        }/bin/git-credential-libsecret";
    };
  };
}
