{ ... }:

# logind turns every sleep request down, so an idle hook or a stray key
# never puts the GPU into a state the driver has to recover from.
{
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };
}
