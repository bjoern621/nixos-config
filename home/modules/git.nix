{ pkgs, lib, ... }:

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
        name = "Björn";
        email = "41452212+bjoern621@users.noreply.github.com";
      };
      init.defaultBranch = "main";

      pull.rebase = true; # Rebases local commits on top of the remote. Linear history, no merge commits.
      rebase.autoStash = true; # makes rebase-pulls stash dirty files, pull, then unstash. Removes the clean-tree requirement (git pull --rebase doesn't work if there are uncommitted changes), at the cost of occasional stash-pop conflicts.

      # Configure git-credential-helper with libsecret
      # Allows storing the git password and not needing to retype it over and over again
      # https://github.com/NixOS/nixpkgs/pull/236850#issuecomment-2398121923
      credential.helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";

      # Use secretservice credential store with GCM
      # Works with e.g. gnome-keyring
      credential.credentialStore = "secretservice";
    };

    # Author email per forge.
    # No per-repo setup on clone.
    includes =
      let
        # GitLab private commit email.
        # Keeps a reachable address out of published history.
        gitlab.user.email = "2-bjoern@users.noreply.gitlab.tail115f30.ts.net";
        # `**` spans slashes only as whole path component,
        # so scp form needs `*` for namespace segment.
        urlForms = host: [
          "https://${host}/**"
          "ssh://git@${host}/**"
          "git@${host}:*/**"
        ];
        # Both names reach the same instance.
        hosts = [
          "gitlab.bjoernblessin.de"
          "gitlab.pidgemail.com"
          "gitlab.tail115f30.ts.net"
        ];
      in
      map (url: {
        condition = "hasconfig:remote.*.url:${url}";
        contents = gitlab;
      }) (lib.concatMap urlForms hosts);
  };
}
