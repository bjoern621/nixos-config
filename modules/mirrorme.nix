{ inputs, ... }:

{
  imports = [ inputs.mirrorme.nixosModules.mirrorme ];

  # Enables the ffmpeg wrapper that has CAP_SYS_ADMIN to allow capturing the screen without root privileges.
  programs.mirrorme.kmsgrab.enable = true;

  # Adds the mirrorme group to the user so that the user can use the ffmpeg wrapper.
  users.users.bjoern.extraGroups = [ "mirrorme" ];

  # Keeps the icon out of the system tray whatever the in-app switch holds, so closing the window ends the app.
  environment.sessionVariables.MIRRORME_TRAY = "0";
}
