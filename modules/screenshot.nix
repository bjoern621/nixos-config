{ pkgs, ... }:

{
    environment.systemPackages = use pkgs; [
      swappy # Screenshot editing
      grim # Capture image from screen
      slurp # Area selection tool, outputting coordinates to grim
    ];
}