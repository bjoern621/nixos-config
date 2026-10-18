{ pkgs, ... }:

# MT7927 (Filogic 380) Bluetooth firmware.
# BT half is USB device 0489:e13a, hardware variant 0x6639.
# linux-firmware ships only WiFi blobs under mediatek/mt7927/.
# BT blob sat in draft MR !946, closed unmerged pending MediaTek redistribution sign-off.
# Without it btmtk fails with -ENOENT and resets chip in loop.
# Chip then wedges, stops answering USB enumeration (error -110 / -71) across warm reboots.
# Recovery: power off, cut PSU ~30 s.
# Drop once linux-firmware carries mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin.

let
  btFirmware = pkgs.fetchurl {
    # MR !946 head commit; blob extracted from ASUS MT7925/MT7927 Windows driver V5603998.
    url = "https://gitlab.com/jetm/linux-firmware/-/raw/77ad2a92acf2ac3e5ea47432b43d925ff99db909/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin";
    hash = "sha256-ZpxcmaDFnIXBKF09G4sxkVwtMTQaIkT07dy/1g/7vHY=";
  };
in
{
  hardware.firmware = [
    (pkgs.runCommand "mt7927-bluetooth-firmware" { } ''
      install -Dm644 ${btFirmware} $out/lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin
    '')
  ];
}
