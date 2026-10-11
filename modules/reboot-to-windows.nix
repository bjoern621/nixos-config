{ pkgs, ... }:

# Windows sits on its own disk with its own ESP, and lanzaboote carries no entry for it.
# BootNext points the firmware at the Windows Boot Manager for one boot, then the default returns.
let
  rebootToWindows = pkgs.writeShellApplication {
    name = "reboot-to-windows";
    runtimeInputs = [
      pkgs.efibootmgr
      pkgs.gnused
      pkgs.systemd
    ];
    text = ''
      entry=$(efibootmgr | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\? *Windows Boot Manager.*/\1/p' | head -n 1)
      if [ -z "$entry" ]; then
        echo "The firmware boot list holds no Windows Boot Manager entry. Check it with efibootmgr." >&2
        exit 1
      fi
      efibootmgr --quiet --bootnext "$entry"
      systemctl reboot
    '';
  };
in
{
  environment.systemPackages = [ rebootToWindows ];
}
