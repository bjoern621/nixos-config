{ pkgs, ... }:

{
  hardware.firmware = [
    pkgs.sof-firmware
  ];

  environment.systemPackages = with pkgs; [
    alsa-utils # ALSA, the Advanced Linux Sound Architecture utils
    easyeffects # Audio effects
    pwvucontrol # Pipewire Volume Control
    coppwr # Low level control GUI for the PipeWire multimedia server
  ];

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    wireplumber.enable = true;
    alsa.enable = true;
    alsa.support32Bit = false;
    pulse.enable = true; # ! Definitely required by hyprland / waybar (https://github.com/Alexays/Waybar/issues/3431#issuecomment-2223092688) !
    jack.enable = false;
  };
}
