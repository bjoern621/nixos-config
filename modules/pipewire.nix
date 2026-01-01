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
    pulse.enable = false;
    jack.enable = false;
  };
}
