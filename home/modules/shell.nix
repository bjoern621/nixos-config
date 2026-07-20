{ pkgs, ... }:

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
    historyWidget.options = [
      "--sort"
      "--exact"
    ];
  };
}
