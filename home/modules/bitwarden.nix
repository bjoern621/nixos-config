{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bitwarden-desktop
  ];

  # Bitwarden treats an unset "start automatically on login" as on:
  # openAtLogin$ maps null to !isDev().
  # It rewrites ~/.config/autostart/bitwarden.desktop on every launch.
  # Hidden=true is the XDG override; systemd-xdg-autostart-generator skips the entry.
  # Bitwarden's rewrite hits a store symlink and fails with EROFS.
  # With the setting off it unlinks the file; next activation restores it.
  # force: Bitwarden may have left a plain file here before activation.
  xdg.configFile."autostart/bitwarden.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Bitwarden
      Exec=bitwarden
      Hidden=true
    '';
  };
}
