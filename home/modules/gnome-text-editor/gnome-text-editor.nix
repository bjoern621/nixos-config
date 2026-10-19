{ pkgs, ... }:

{
  home.packages = [
    # Window close and Ctrl+Q skip unsaved-changes dialog while restore-session is on.
    # Unsaved tabs persist as drafts and reopen on next start.
    (pkgs.gnome-text-editor.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./close-without-asking.patch ];
    }))
  ];
}
