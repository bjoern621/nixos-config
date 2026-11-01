# Boot hang with CalDigit TS5 Plus on ASM4242 USB4 port at power-on.
# Firmware tunnels dock's PCIe switch before kernel starts.
# thunderbolt resets host router on probe, tearing tunnel down under live devices:
# dock ports fail D3hot -> D0, board's USB4 _PS3 loops into AE_AML_LOOP_TIMEOUT,
# udev workers block and cryptroot times out into emergency mode.
{
  boot.kernelParams = [
    # Driver keeps firmware's tunnels.
    "thunderbolt.host_reset=false"
    # No power management on PCIe ports, so board's USB4 _PS3 never runs.
    "pcie_port_pm=off"
  ];
}
