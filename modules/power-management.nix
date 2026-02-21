{ pkgs, ... }:

{
  # See also: https://wiki.nixos.org/wiki/Laptop#Power_management

  powerManagement.enable = true;

  # "TLP is a feature-rich utility for Linux, saving laptop battery power without the need to delve deeper into technical details."
  # "Has sensible defaults for most laptops."
  services.tlp = {
    enable = true;
    settings = {
      # Disable audio power saving to prevent audio quality degradation
      SOUND_POWER_SAVE_ON_AC = 0;
      SOUND_POWER_SAVE_ON_BAT = 0;
    };
  };

  # Disable runtime power management for TAS2781 speaker amplifier.
  # The TAS2781 DSP firmware state is lost when the device suspends,
  # causing tinny/no-bass audio until driver rebind.
  #   services.udev.extraRules = ''
  #     ACTION=="add", SUBSYSTEM=="i2c", KERNEL=="i2c-TIAS2781:00", ATTR{power/control}="on"
  #   '';

  # Rebind TAS2781 speaker amplifier driver after system resume.
  # The TAS2781 DSP firmware is not properly restored after S3/s2idle suspend.
  #   systemd.services.tas2781-resume = {
  #     description = "Rebind TAS2781 speaker amplifier after resume";
  #     wantedBy = [ "post-resume.target" ];
  #     after = [ "post-resume.target" ];
  #     serviceConfig = {
  #       Type = "oneshot";
  #       ExecStart = "${pkgs.bash}/bin/bash -c 'echo i2c-TIAS2781:00 > /sys/bus/i2c/drivers/tas2781-hda/unbind; sleep 0.5; echo i2c-TIAS2781:00 > /sys/bus/i2c/drivers/tas2781-hda/bind'";
  #     };
  #   };
}
