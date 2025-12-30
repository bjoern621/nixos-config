{ pkgs, ... }:

{
  # https://nixos.wiki/wiki/Git

  home.packages = with pkgs; [
    git
    git-credential-manager
  ];

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
      credential.helper = "${pkgs.git-credential-manager}/bin/git-credential-manger";
    };
  };
}
