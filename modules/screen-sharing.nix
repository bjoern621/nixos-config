{ inputs, ... }:

{
  imports = [ inputs.screen-sharing.nixosModules.mirrorme ];

  # Enables the ffmpeg wrapper that has CAP_SYS_ADMIN to allow capturing the screen without root privileges.
  programs.mirrorme.kmsgrab.enable = true;

  # Adds the mirrorme group to the user so that the user can use the ffmpeg wrapper.
  users.users.bjoern.extraGroups = [ "mirrorme" ];
}
