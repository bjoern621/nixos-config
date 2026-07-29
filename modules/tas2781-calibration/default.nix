# TAS2781 smart amp factory speaker calibration.
# Yoga Slim 7 14APU8 stores per-speaker calibration in EFI variable CALI_DATA (Lenovo GUID).
# Blob is V1 layout: 4 devices x 20 bytes, then timestamp and CRC words.
# Lenovo left both words zero. Kernel CRC check fails, calibration discarded ("tas2781_apply_calib: V1 CRC error").
# Amp excursion + thermal protection then runs uncalibrated; loud deep bass crackles.
# Patch accepts V1 blob when both words zero and data non-empty.
# Verify after boot: journalctl -kb shows "V1 data without CRC, accepted".
{ ... }:

{
  boot.kernelPatches = [
    {
      name = "tas2781-cali-v1-zero-crc";
      patch = ./v1-zero-crc.patch;
    }
  ];
}
