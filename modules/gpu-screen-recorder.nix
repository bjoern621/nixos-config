{ pkgs, ... }:

# Note: the replay service and its save binds live in home/modules/gpu-screen-recorder.nix.
{
  programs.gpu-screen-recorder.enable = true;
  environment.systemPackages = [ pkgs.gpu-screen-recorder-gtk ];
}
