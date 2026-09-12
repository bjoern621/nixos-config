{ ... }:

# Kernel crash handling: panic, dump, reboot.
# Default handling kills the oopsing task and leaves the rest spinning on its locks.
# During hibernate entry that means console suspended, userspace frozen, no log,
# fans at full speed until the power button is held.
# efi-pstore takes the dmesg tail at panic time.
# systemd-pstore archives it on the next boot under /var/lib/systemd/pstore/<epoch>/001/dmesg.txt, root only.
#
# Split with TLP: the hardlockup detector rides on the NMI watchdog,
# and TLP rewrites kernel.nmi_watchdog on every AC/battery switch (NMI_WATCHDOG, default 0).
# hung_task fires on a task in D state for kernel.hung_task_timeout_secs (120 s).

{
  boot.kernel.sysctl = {
    "kernel.panic_on_oops" = 1;
    "kernel.softlockup_panic" = 1;
    "kernel.hardlockup_panic" = 1;
    "kernel.hung_task_panic" = 1;
    # Seconds until reboot after panic.
    "kernel.panic" = 30;
  };

  services.tlp.settings.NMI_WATCHDOG = 1;
}
