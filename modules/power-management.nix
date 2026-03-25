{ pkgs, ... }:

{
  # See also: https://wiki.nixos.org/wiki/Laptop#Power_management

  powerManagement.enable = true;

  # Prevent runtime PM from suspending the TAS2781 speaker amplifier.
  # Its DSP firmware state is not restored properly, causing tinny audio.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="i2c", KERNEL=="i2c-TIAS2781:00", ATTR{power/control}="on"
  '';

  services.tlp = {
    enable = true;
    settings = {
      # --- CPU ---
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # Energy Performance Preference (amd-pstate-epp)
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Disable turbo boost on battery to reduce power spikes
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # Allow CPU to clock down to minimum on battery
      CPU_SCALING_MIN_FREQ_ON_BAT = 400000;

      # --- Platform profile ---
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # --- Audio ---
      # Disable audio power saving — the TAS2781 speaker amplifier
      # loses DSP firmware state when the HDA codec suspends.
      SOUND_POWER_SAVE_ON_AC = 0;
      SOUND_POWER_SAVE_ON_BAT = 0;

      # --- WiFi ---
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";

      # --- PCIe ---
      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # --- Runtime PM for PCI(e) devices ---
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";

      # --- USB autosuspend ---
      USB_AUTOSUSPEND = 1;

      # --- GPU ---
      RADEON_DPM_STATE_ON_AC = "performance";
      RADEON_DPM_STATE_ON_BAT = "battery";
      RADEON_DPM_PERF_LEVEL_ON_AC = "auto";
      RADEON_DPM_PERF_LEVEL_ON_BAT = "low";
    };
  };
}
