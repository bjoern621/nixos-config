{ pkgs, ... }:

{
    # Hotkey is set in keybinds.nix

    environment.systemPackages = with pkgs; [
      swappy # Screenshot editing
      grim # Capture image from screen
      slurp # Area selection tool, outputting coordinates to grim
    ];
}