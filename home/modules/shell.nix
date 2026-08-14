{ lib, pkgs, ... }:

let
  fdCommand =
    type:
    lib.concatStringsSep " " [
      (lib.getExe pkgs.fd)
      "--type ${type}"
      "--hidden"
      "--one-file-system"
      "--exclude .git"
      # Anchored to the search root, so only the real mount is skipped.
      "--exclude mnt/garage"
    ];
in
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
    };
    initContent = ''
      # Word navigation
      bindkey '^[[1;5D' backward-word
      bindkey '^[[1;5C' forward-word
      # Word deletion.
      # Alacritty sends ^H for Ctrl+Backspace, CSI 3;5~ for Ctrl+Del.
      bindkey '^H' backward-kill-word
      bindkey '^[[3;5~' kill-word
    '';
  };

  # Fuzzy finder - enables Ctrl+R (history), Ctrl+T (files), Alt+C (cd)
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--height 40%"
      "--border"
    ];
    # fzf's builtin walker follows symlinks and crosses mounts.
    # From ~ that pulls /nix/store in through .nix-profile,
    # and lists the whole S3 bucket behind ~/mnt/garage over the network.
    # fd never follows symlinks, --one-file-system stops at any mount point.
    # mnt/garage also excluded by name: a wedged rclone backend blocks even the
    # stat that --one-file-system needs to spot the crossing.
    fileWidget.command = fdCommand "f";
    changeDirWidget.command = fdCommand "d";
    historyWidget.options = [
      "--sort"
      "--exact"
    ];
  };
}
