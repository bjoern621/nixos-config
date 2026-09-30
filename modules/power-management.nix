{ pkgs, ... }:

{
  # See also: https://wiki.nixos.org/wiki/Laptop#Power_management

  powerManagement.enable = true;

  # The RTL8852CE WiFi card and the 0bda:5852 Bluetooth radio are the same
  # Realtek combo chip sharing one antenna, so they cause A2DP audio stutter
  # (e.g. Anker Soundcore Boost) under power saving:
  #
  #   - rtw89 firmware power-save mode disrupts the WiFi/Bluetooth coexistence
  #     scheduler, starving Bluetooth transport slots. disable_ps_mode=1 keeps
  #     the coexistence timing stable.
  #   - PCIe ASPM L1 substates put the card's PCIe link into deep sleep
  #     (L1.2, ~150us wake latency). With TLP forcing PCIE_ASPM_ON_BAT to
  #     "powersupersave" the wake latency makes the card miss coexistence
  #     deadlines, logged as "timed out to flush queues" / "RXDCK timeout",
  #     and the Bluetooth audio drops out. disable_aspm_l1/l1ss call
  #     pci_disable_link_state() so the states stay off even when TLP
  #     re-applies its ASPM policy on AC/battery transitions.
  boot.extraModprobeConfig = ''
    options rtw89_core disable_ps_mode=1
    options rtw89_pci disable_aspm_l1=1 disable_aspm_l1ss=1
  '';

  # Samsung PM9A1 (MZVL21T0HCLR, fw CL1QGXA7) at times goes controller-fatal:
  # "nvme nvme0: controller is down; will reset: CSTS=0x3".
  # Failed reset takes / with it: black screen, nothing in journal, no pstore dump.
  # APST off alone did not stop it; 2026-09-30 fault hit on battery with PCIe link in ASPM L1.2.
  # Fix: APST off plus ASPM L1.1/L1.2 off on its link (udev rule below).
  # Clearing link/*_aspm sets aspm_disable, which TLP's policy writes on AC/battery switch keep.
  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=0" ];

  # Prevent runtime PM from suspending the TAS2781 speaker amplifier.
  # Its DSP firmware state is not restored properly, causing tinny audio.
  #
  # The battery (PNP0C0A) and Synaptics touchpad (SYNA2BA6) rules remove both
  # devices as wake sources. With them armed, any suspend attempt aborts
  # within the same second: the EC raises a battery status notification
  # (GPE09, ACPI SCI / IRQ 9) as power draw changes on suspend, which counts
  # as a wake event. Lid open and the power button remain armed.
  #
  # s2idle stays unusable on this machine even with these rules (the platform
  # never reaches s0ix, "Wakeup unrelated to ACPI SCI"), which is why lid
  # close hibernates directly (modules/hibernate.nix). The rules are kept for
  # the case that a BIOS update fixes s0ix and suspend gets re-enabled.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="i2c", KERNEL=="i2c-TIAS2781:00", ATTR{power/control}="on"
    ACTION=="add|change", SUBSYSTEM=="platform", KERNEL=="PNP0C0A:00", ATTR{power/wakeup}="disabled"
    ACTION=="add|change", SUBSYSTEM=="i2c", KERNEL=="i2c-SYNA2BA6:00", ATTR{power/wakeup}="disabled"
    ACTION=="add|change", SUBSYSTEM=="pci", ATTR{vendor}=="0x144d", ATTR{device}=="0xa80a", ATTR{link/l1_2_aspm}="0", ATTR{link/l1_1_aspm}="0"
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
      # ideapad_laptop maps profile to EC power mode, which owns fan curve.
      # low-power picks EC quiet curve: fan barely ramps under sustained
      # load, chassis soaks until untouchable. Only balanced/performance
      # let EC spin fan up. CPU_* keys above cannot compensate; they cut
      # heat production, not heat removal.
      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "performance";

      # --- Audio ---
      # Disable audio power saving — the TAS2781 speaker amplifier
      # loses DSP firmware state when the HDA codec suspends.
      SOUND_POWER_SAVE_ON_AC = 0;
      SOUND_POWER_SAVE_ON_BAT = 0;

      # --- WiFi ---
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off";

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
      RADEON_DPM_PERF_LEVEL_ON_BAT = "auto";
    };
  };
}
