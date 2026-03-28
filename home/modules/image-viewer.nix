{ pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    qimgv
  ];

  # Merge a single setting without replacing the full config (qimgv writes its own config at runtime)
  home.activation.qimgvConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    config="$HOME/.config/qimgv/qimgv.conf"
    if [ -f "$config" ]; then
      if $DRY_RUN_CMD grep -q "^infoBarWindowed=" "$config"; then
        $DRY_RUN_CMD ${pkgs.gnused}/bin/sed -i 's/^infoBarWindowed=.*/infoBarWindowed=true/' "$config"
      else
        $DRY_RUN_CMD ${pkgs.gnused}/bin/sed -i '/^\[General\]/a infoBarWindowed=true' "$config"
      fi
    fi
  '';

  wayland.windowManager.hyprland.settings.windowrule = [
    "float on, match:class qimgv"
  ];
}
