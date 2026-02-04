{ config, pkgs, ... }:

let
  sysconf-audio-fix = pkgs.writeShellScriptBin "sysconf-audio-fix" ''
    # Reload TAS2781 speaker amplifier driver to fix tinny/no-bass audio.
    # This is a workaround for a kernel driver bug where DSP firmware
    # state is not properly restored after system suspend.
    set -euo pipefail

    DEVICE="i2c-TIAS2781:00"
    DRIVER_PATH="/sys/bus/i2c/drivers/tas2781-hda"

    if [[ ! -d "$DRIVER_PATH" ]]; then
      echo "TAS2781 driver not found at $DRIVER_PATH" >&2
      exit 1
    fi

    echo "Unbinding TAS2781 amplifier..."
    echo "$DEVICE" | sudo tee "$DRIVER_PATH/unbind" > /dev/null

    sleep 0.5

    echo "Rebinding TAS2781 amplifier..."
    echo "$DEVICE" | sudo tee "$DRIVER_PATH/bind" > /dev/null

    echo "TAS2781 amplifier reloaded. Audio should be fixed."
  '';
in
{
  environment.systemPackages = [ sysconf-audio-fix ];
}
