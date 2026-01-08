{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    mission-center
  ];
}
