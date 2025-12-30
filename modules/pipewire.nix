{ pkgs, ... }:

{
  hardware.firmware = [
    pkgs.sof-firmware
  ];

  environment.systemPackages = with pkgs; [
    alsa-utils
    easyeffects
    pavucontrol
    pwvucontrol
  ];

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    wireplumber.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    media-session.enable = false;
  };
}
